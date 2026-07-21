codeunit 50016 "FSN CallCenter Controller"
{
    SingleInstance = true;
    TableNo = "LSC POS Menu Line";
    trigger OnRun()
    begin
        case Command of
            'CHANNEL_LKP':
                ShowChannel();
            'CHANNEL_SELECT':
                ChannelSelectedPressed();
            'NEWNOCONFIRM':
                begin
                    ePosControlInterface.ShowPanelModal('#FSNLOGIN', 'NEWNOCONFIRM');
                end;
        end;
    end;

    var
        GlobalReceipt: Code[20];
        DeliveryOrderTmp: Record "LSC Delivery Order" temporary;
        DeliveryOrderManagement: Codeunit "LSC Delivery Order Management";
        DelContTmp: Record Contact temporary;
        DeliveryType: option " ",Home,Work,Other,Takeaway;
        FSNSalesChannel: Record "FSN Sales Channel";
        DeliveryOrder: Record "LSC Delivery Order";
        PosSetup: Record "FSN POS Setup Extend";
        GrupoSalesMember: Record "LSC Cmsn Salesp. Grp Member";
        GrupoSalesMemberTmp: Record "LSC Cmsn Salesp. Grp Member" temporary;
        POSInfocodeTmpAll: Record "LSC Infocode" temporary;
        POSInfocodeTmpStaff: Record "LSC Infocode" temporary;
        POSSESSION: Codeunit "LSC POS Session";
        POSGUI: Codeunit "LSC POS GUI";
        POSTransaction: Codeunit "LSC POS Transaction";
        StepProcess: Option Input,ByStaff,All;
        lTxt1: Label 'Cant load order';
        lTxt2: Label 'Order %1 not exists';
        lTxt3: Label 'None';
        lTxt4: Label 'You dont have permissions';
        lTxt5: Label 'Enter Ticket no.';
        lTxt6: Label 'Lookup setup Channel not found';
        AlterKey: Integer;
        posc: Codeunit "LSC Delivery Order Management";
        DelContTEMP: Record Contact temporary;
        DelCont: Record Contact;
        RecRef: RecordRef;
        EPosCtrl: Codeunit "LSC POS Control Interface";
        EPosContext: Codeunit "LSC POS Context";
        HospitalityPOSGUI: codeunit "LSC Hospitality POS GUI";
        STATE: Option CreateNew,Confirm,Edit,Cancel;
        DelPosPanelsUtility: Codeunit "LSC Del. POS Panel Utilities";
        DeliveryOrderTemp: Record "LSC Delivery Order" temporary;
        CC: Codeunit "LSC Offl. CC Web Serv. Req";
        GlobalParametroPQ: Record "FSN Parameter";
        ePosControlInterface: Codeunit "LSC POS Control Interface";

    procedure VoidTransaction(PosTrans: Record "LSC POS Transaction")
    var
        POSPostUtility: Codeunit "LSC POS Post Utility";
        DelPosComm: codeunit "LSC Delivery POS Commands";
        CancelWSProcess: Boolean;
        DelivOrder: Record "LSC Delivery Order";
        DeliveryPosComand: Codeunit "LSC Delivery POS Commands";
        WarningCode: Code[10];
        WarningText: text;
        POSMenulineTemp: Record "LSC POS Menu Line" temporary;
        HospiPOSStartup: codeunit "LSC Hospitality POS Startup";
        Parameter: Record "FSN Parameter";
        POSTransactionCodeunit: Codeunit "LSC POS Transaction";
        Parametros: Record "FSN Parameter";
        FSNWebTable: Record "FSN WebServiceTable";
    begin
        PosTrans.Reset();
        PosTrans.SetRange(PosTrans."Sales Staff", POSSESSION.StaffID());
        if Parametros.Get('NEWCONFIRT', 'DIAS') then begin
            IF Parametros.Valor <> '' THEN
                PosTrans.SetRange(PosTrans."Trans. Date", CalcDate('-' + Parametros.Valor + 'D', Today), Today);
        end;
        if PosTrans.find('-') then begin
            repeat
                if not FSNWebTable.get(PosTrans."Receipt No.") then
                    IF DelivOrder.Get(PosTrans."Receipt No.") THEN begin
                        IF DelivOrder."Call Cent. Web Service Status" = DelivOrder."Call Cent. Web Service Status"::"New-Not Confirmed" THEN
                            DeliveryPosComand.CancelOrder(DelivOrder, true, false, WarningCode, WarningText);
                    end;
            until PosTrans.Next() = 0;
        end;

        POSMenulineTemp.Init();
        POSMenulineTemp."Profile ID" := 'FASANI';
        POSMenulineTemp.Command := 'HOSP-SEARCHRESET';
        POSMenulineTemp.Description := 'Reiniciar';
        HospiPOSStartup.run(POSMenulineTemp);
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
        lText002: Label 'El usuario%1 no es MANAGER';
        Text019: Label 'Error en las credenciales %1';
        pInt: Integer;
        tStaff: Record "LSC Staff";
        POSTrans: Record "LSC POS Transaction";
    begin

        if (payload = 'NEWNOCONFIRM') and (panelID = '#FSNLOGIN') then begin
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
                    ePOSControlInterface.SetInputText(POSSession.StaffInputID, '');
                    ePOSControlInterface.SetInputText(POSSession.PasswordInputID, '');
                    exit;
                end;

                tStaff.Reset();
                tStaff.SetCurrentKey(ID);
                tStaff.SetRange(ID, StaffID);
                tStaff.SetRange("Permission Group", 'MANAGER');
                IF NOT (tStaff.FINDFIRST) AND (EVALUATE(pInt, StaffID)) THEN BEGIN
                    POSGUI.PosMessage(STRSUBSTNO(lText002, StaffID));
                    ePOSControlInterface.SetInputText(POSSession.StaffInputID, '');
                    ePOSControlInterface.SetInputText(POSSession.PasswordInputID, '');
                    EXIT;
                END;

                VoidTransaction(POSTrans);
                ePOSControlInterface.SetInputText(POSSession.StaffInputID, '');
                ePOSControlInterface.SetInputText(POSSession.PasswordInputID, '');
            end;
        end;
    end;

    procedure ProcessInputOnSelectingOrderOnOrderTaking()
    var
        PanelResponse: Integer;
        SelOrderID: Code[20];
    begin
        DelPosPanelsUtility.GetOpenOrderResponse(SelOrderID, PanelResponse);
        if DeliveryOrder.Get(SelOrderID) then;
        case PanelResponse of
            0:
                STATE := STATE::Cancel;
            1:
                begin
                    STATE := STATE::CreateNew;
                end;
            2:
                STATE := STATE::Edit;
            else
                exit;  //cancel
        end;
    end;

    /*procedure ShowSelectedOrder()
    begin
        Clear(DelContTEMP);
        DelContTEMP.DeleteAll;
        DelContTEMP := DelCont;
        DelContTEMP.Insert;
        if STATE = STATE::Cancel then
            exit;
        if STATE = STATE::Edit then begin
            DelCont.reset;
            DelCont.SetRange(DelCont."No.", DeliveryOrder."Phone No.");
            if DelCont.FindFirst() then
                NextOrderDate(DelCont);
        end;

        if STATE = STATE::CreateNew then begin
            DelCont.reset;
            DelCont.SetRange(DelCont."No.", DeliveryOrder."Phone No.");
            if DelCont.FindFirst() then
                NextOrderDate(DelCont);
        end;
        Commit;
    END;*/

    /*procedure NextOrderDate(DelContTEMP2: Record Contact temporary): Boolean
    var
        ErrorText: Text;
        PageDelivery: Page "FSN Edit Delivery Order List";
    begin
        IF DeliveryOrder.GET(POSSESSION.GetValue('CURRORDER')) THEN BEGIN
            PageDelivery.SETGLOBALVALUE(DeliveryOrder);
            PageDelivery.RUN;
            exit(true);
        END
    end;*/

    procedure SetDeliveryOrderTmp(pdeliveryOrderTmp: Record "LSC Delivery Order" temporary)
    begin
        DeliveryOrderTmp := pdeliveryOrderTmp;
    end;

    procedure GetDeliveryOrderTmp(var pdeliveryOrderTmp: Record "LSC Delivery Order" temporary)
    begin
        pdeliveryOrderTmp := DeliveryOrderTmp;
    end;

    procedure SetContactTmp(pDelContTmp: Record Contact temporary)
    begin
        DelContTmp := pDelContTmp;
    end;

    procedure GetContactTmp(pDelContTmp: Record Contact temporary)
    begin
        pDelContTmp := DelContTmp;
    end;

    procedure setDeliveryType(pDeliveryType: option " ",Home,Work,Other,Takeaway)
    begin
        DeliveryType := pDeliveryType;
    end;

    procedure getDeliveryType(): Integer
    begin
        exit(DeliveryType);
    end;

    procedure ClearData()
    begin
        DeliveryType := DeliveryType::" ";
        AlterKey := 0;
    end;

    procedure ChannelSelectedPressed()
    begin
        if DeliveryOrder."Order No." = '' then
            exit;
        ChannelSelection(DeliveryOrder."Order No.");
    end;

    procedure ChannelSelection(OrderNo: Code[20])
    var
        InfocodeSelection: Record "LSC Infocode";
        lJsonBuffer: Record "JSON Buffer" temporary;
        JsonTextReader: Codeunit "Json Text Reader/Writer";
        RecCode: Code[20];
        Description: Text[50];
        InfocodeRef: RecordRef;
        InfoKey: RecordId;
        jArray: JsonArray;
        jString: text;
        Ok: Boolean;
    begin
        Clear(Description);
        Clear(jArray);
        Clear(Ok);
        InfocodeRef.GetTable(InfocodeSelection);
        POSGUI.GetActiveLookupMarkedRecords(jArray, false);
        jArray.WriteTo(jString);
        JsonTextReader.ReadJSonToJSonBuffer(jString, lJsonBuffer);
        if lJsonBuffer.Find('-') then
            repeat
                if lJsonBuffer."Token type" = lJsonBuffer."Token type"::String then
                    if lJsonBuffer.Value <> '' then begin
                        EVALUATE(InfoKey, lJsonBuffer.Value);
                        InfocodeRef := InfoKey.GetRecord();
                        if CopyStr(InfocodeRef.Field(InfocodeSelection.FieldNo(Code)).Value, 1, 1) = '.' then begin
                            exit;
                        end;

                        if StepProcess = StepProcess::ByStaff then begin
                            RecCode := InfocodeRef.Field(InfocodeSelection.FieldNo(Code)).Value;
                            if POSInfocodeTmpStaff.Get(RecCode) then;
                            Description := POSInfocodeTmpStaff.Description;
                        end else begin
                            RecCode := InfocodeRef.Field(InfocodeSelection.FieldNo(Code)).Value;
                            if POSInfocodeTmpAll.Get(RecCode) then;
                            Description := POSInfocodeTmpAll.Description;
                        end;

                        SaveChannel(OrderNo
                            , InfocodeRef.Field(InfocodeSelection.FieldNo(Code)).Value
                            , Description
                            , false, '')
                    end;
            until lJsonBuffer.Next() = 0;

        InfocodeRef.Close();
        if not FSNSalesChannel.Get(DeliveryOrder."Order No.") then begin
            ShowChannelByType(false);
        end;
    end;

    procedure ShowChannel()
    var
        StaffID: Code[20];
        InputRequire: Boolean;
    begin
        StepProcess := StepProcess::Input;
        if POSSESSION.GetValue('CURRORDER') = '' then begin
            POSGUI.PosMessage(lTxt1);
            exit;
        end;
        if not DeliveryOrder.get(POSSESSION.GetValue('CURRORDER')) then begin
            POSGUI.PosMessage(StrSubstNo(lTxt2, POSSESSION.GetValue('CURRORDER')));
            exit;
        end;
        if TestSalesChannel(DeliveryOrder) then
            exit;

        StaffID := POSSESSION.StaffID();
        if StaffID = '' then
            StaffID := DeliveryOrder."Order Taker";
        if StaffID = '' then
            exit;

        CLEAR(GrupoSalesMemberTmp);
        GrupoSalesMemberTmp.RESET;
        GrupoSalesMemberTmp.DELETEALL;

        GrupoSalesMember.RESET;
        GrupoSalesMember.SETRANGE(GrupoSalesMember."No.", StaffID);
        IF GrupoSalesMember.FIND('-') THEN
            REPEAT
                GrupoSalesMemberTmp.INIT;
                GrupoSalesMemberTmp := GrupoSalesMember;
                IF GrupoSalesMemberTmp.INSERT THEN;
            UNTIL GrupoSalesMember.NEXT = 0;

        IF NOT GrupoSalesMemberTmp.FIND('-') THEN BEGIN
            POSGUI.PosMessage(lTxt4);
            exit;
        END;
        FillTableSalesChannelOption(StaffID, false);
        if POSInfocodeTmpStaff."Mobile - Display Required" then begin
            POSGUI.OpenAlphabeticKeyboard(lTxt5, '', false, 'SCHANNEL_TK', 250);
            StepProcess := StepProcess::Input;
        end else
            ShowChannelByType(true);
    end;

    local procedure ShowChannelByType(byStaff: Boolean)
    var
        InfocodeRef: RecordRef;
        coupon: Record "LSC Coupon Header";
    begin
        //false = all
        PosSetup.SETCURRENTKEY(Type, "Line Type", "From Date", "Value No.", "Line No.", "Store No.");
        PosSetup.SETRANGE(PosSetup.Type, PosSetup.Type::CallCenter);
        PosSetup.SETRANGE(PosSetup."Line Type", PosSetup."Line Type"::Parameter);
        PosSetup.SETRANGE(PosSetup."From Date", 0D);
        PosSetup.SETRANGE(PosSetup."Value No.", 'CHANNEL_LOOKUP');
        if not PosSetup.FindFirst() then begin
            POSGUI.PosMessage(lTxt6);
        end;

        if byStaff then begin
            InfocodeRef.GetTable(POSInfocodeTmpStaff);
            StepProcess := StepProcess::ByStaff;

        end
        else begin
            InfocodeRef.GetTable(POSInfocodeTmpAll);
            StepProcess := StepProcess::All;
        end;

        POSTransaction.LookUpEx(true, PosSetup."Value Reference No.", '', InfocodeRef);
    end;

    procedure TestSalesChannel(DelOrder_l: Record "LSC Delivery Order"): Boolean
    begin
        IF (STRPOS(DelOrder_l."Order No.", 'APP') > 0) OR
          (STRPOS(DelOrder_l."Order No.", '000PV#1000') > 0) THEN BEGIN
            PosSetup.RESET;
            PosSetup.SETCURRENTKEY(Type, "Line Type", "From Date", "Value No.", "Line No.", "Store No.");
            PosSetup.SETRANGE(PosSetup.Type, PosSetup.Type::CallCenter);
            PosSetup.SETRANGE(PosSetup."Line Type", PosSetup."Line Type"::Parameter);
            PosSetup.SETRANGE(PosSetup."From Date", 0D);
            PosSetup.SETRANGE(PosSetup."Value No.", 'CHANNELTYPE');
            IF (STRPOS(DelOrder_l."Order No.", 'APP')) > 0 THEN
                PosSetup.SETRANGE(PosSetup."Line No.", 5)
            ELSE
                PosSetup.SETRANGE(PosSetup."Line No.", 8);
            IF PosSetup.FIND('-') THEN
                SaveChannel(DelOrder_l."Order No.", FORMAT(PosSetup."Line No."), PosSetup."Data Extra 1", FALSE, '##DEFAULT');

            IF FSNSalesChannel.GET(DelOrder_l."Order No.") THEN
                EXIT(TRUE);
        END;

    end;

    procedure SaveChannel(Receipt: Code[20]; ResulText: Text; ResulDescription: Text; pPendingProcess: Boolean; pTicketNo: Code[30])
    var
        cDelOrder: Record "LSC Delivery Order";
        pDelOrder: Record "LSC Posted Delivery Order";
        SalesChan: Record "FSN Sales Channel";
        TransHdr: Record "LSC Transaction Header";
        POSTrans_l: Record "LSC POS Transaction";
        Exists: Boolean;
    begin

        IF (pTicketNo = '##DEFAULT') AND POSTrans_l.GET(Receipt) THEN BEGIN
            Exists := TRUE;
            CLEAR(cDelOrder);
            cDelOrder.INIT;
            cDelOrder."Order No." := POSTrans_l."Receipt No.";
            cDelOrder."Restaurant No." := POSTrans_l."Store No.";
            cDelOrder."Phone No." := POSTrans_l."Sell-to Contact No.";
            cDelOrder."Order Date" := POSTrans_l."Trans. Date";
            cDelOrder."Contact Pickup Time" := POSTrans_l."Trans Time";
            cDelOrder."Order Taker" := POSTrans_l."Sales Staff";
            POSTrans_l.CALCFIELDS(POSTrans_l.Payment);
            cDelOrder."Amount Incl. VAT" := POSTrans_l.Payment;
        END
        ELSE BEGIN
            CLEAR(Exists);
            IF NOT cDelOrder.GET(Receipt) THEN BEGIN
                IF pDelOrder.GET(Receipt) THEN BEGIN
                    CLEAR(cDelOrder);
                    cDelOrder.INIT;
                    cDelOrder."Order No." := pDelOrder."Order No.";
                    cDelOrder."Restaurant No." := pDelOrder."Restaurant No.";
                    cDelOrder."Phone No." := pDelOrder."Phone No.";
                    cDelOrder."Order Date" := pDelOrder."Order Date";
                    cDelOrder."Contact Pickup Time" := pDelOrder."Contact Pickup Time";
                    cDelOrder."Order Taker" := pDelOrder."Order Taker";
                    cDelOrder."Amount Incl. VAT" := pDelOrder."Amount Incl. VAT";
                    Exists := TRUE;
                END;
            END ELSE
                Exists := TRUE;
        END;
        SalesChan.INIT;
        SalesChan."Receipt No" := cDelOrder."Order No.";
        SalesChan."POS Terminal No" := '';
        SalesChan."Store No" := cDelOrder."Restaurant No.";
        SalesChan.PhoneNo := cDelOrder."Phone No.";
        SalesChan.Date := cDelOrder."Order Date";
        SalesChan.Time := cDelOrder."Contact Pickup Time";
        SalesChan.SalesStaff := cDelOrder."Order Taker";
        SalesChan."Amount Incl. VAT" := cDelOrder."Amount Incl. VAT";
        SalesChan.TypeChannel := ResulText;
        SalesChan.SalesChannel := ResulDescription;
        SalesChan."Pending Processing" := pPendingProcess;
        SalesChan.Ticket := pTicketNo;
        SalesChan.Voided := NOT Exists;
        IF pTicketNo = '##DEFAULT' THEN
            SalesChan.Comment := 'Automatic';
        IF NOT SalesChan.INSERT(TRUE) THEN
            SalesChan.MODIFY(TRUE);

    end;

    procedure FillTableSalesChannelOption(CodStaff: Code[20]; ShowAll: Boolean)
    var
        Channels: Record "FSN POS Setup Extend";
        PermissionChannels: Record "FSN POS Setup Extend";
        ComissionSalesGroup: Record "LSC Cmsn Salesperson Group";
        InputReq: Boolean;
    begin
        POSInfocodeTmpAll.Reset();
        if POSInfocodeTmpAll.Find('-') then
            exit;
        POSInfocodeTmpStaff.Reset();
        if POSInfocodeTmpStaff.Find('-') then
            exit;

        IF NOT ShowAll THEN
            IF GrupoSalesMemberTmp.FIND('-') THEN
                REPEAT
                    IF ComissionSalesGroup.GET(GrupoSalesMemberTmp."Group Code") THEN BEGIN
                        IF NOT InputReq AND ComissionSalesGroup."FSN Require Input" THEN
                            InputReq := ComissionSalesGroup."FSN Require Input";

                        PermissionChannels.RESET;
                        PermissionChannels.SETCURRENTKEY("Value No.", "Store No.", "From Date", "To Date");
                        PermissionChannels.SETRANGE(PermissionChannels.Type, PermissionChannels.Type::CallCenter);
                        PermissionChannels.SETRANGE(PermissionChannels."Line Type", PermissionChannels."Line Type"::Parameter);
                        PermissionChannels.SETRANGE(PermissionChannels."Value No.", 'CHANNELGROUP');
                        PermissionChannels.SETRANGE(PermissionChannels."Store No.", GrupoSalesMemberTmp."Group Code");
                        IF PermissionChannels.FIND('-') THEN
                            REPEAT
                                Channels.RESET;
                                Channels.SETCURRENTKEY(Type, "Line Type", "From Date", "Value No.", "Line No.", "Store No.");
                                Channels.SETRANGE(Channels.Type, Channels.Type::CallCenter);
                                Channels.SETRANGE(Channels."Line Type", Channels."Line Type"::Parameter);
                                Channels.SETRANGE(Channels."From Date", 0D);
                                Channels.SETRANGE(Channels."Value No.", 'CHANNELTYPE');
                                Channels.SETRANGE(Channels."Store No.", '');
                                Channels.SETRANGE(Channels."Line No.", PermissionChannels."Line No.");
                                IF Channels.FIND('-') THEN
                                    REPEAT
                                        IF NOT POSInfocodeTmpStaff.GET(FORMAT(Channels."Line No.")) THEN BEGIN
                                            POSInfocodeTmpStaff.INIT;
                                            POSInfocodeTmpStaff.Code := FORMAT(Channels."Line No.");
                                            POSInfocodeTmpStaff.Description := Channels."Data Extra 1";
                                            POSInfocodeTmpStaff."Input Required" := ComissionSalesGroup."FSN Require Input";

                                            POSInfocodeTmpStaff.INSERT;
                                        END;
                                    UNTIL Channels.NEXT = 0;
                            UNTIL PermissionChannels.NEXT = 0;
                    END;
                UNTIL GrupoSalesMemberTmp.NEXT = 0;
        if InputReq then begin
            POSInfocodeTmpAll.Reset();
            POSInfocodeTmpAll.ModifyAll("Mobile - Display Required", true, false);
        end;

        IF ShowAll THEN BEGIN
            Channels.RESET;
            Channels.SETCURRENTKEY(Type, "Line Type", "From Date", "Value No.", "Line No.", "Store No.");
            Channels.SETRANGE(Channels.Type, Channels.Type::CallCenter);
            Channels.SETRANGE(Channels."Line Type", Channels."Line Type"::Parameter);
            Channels.SETRANGE(Channels."From Date", 0D);
            Channels.SETRANGE(Channels."Value No.", 'CHANNELTYPE');
            Channels.SETRANGE(Channels."Store No.", '');
            IF Channels.FIND('-') THEN
                REPEAT
                    IF NOT POSInfocodeTmpAll.GET(FORMAT(Channels."Line No.")) THEN BEGIN
                        POSInfocodeTmpAll.INIT;
                        POSInfocodeTmpAll.Code := FORMAT(Channels."Line No.");
                        POSInfocodeTmpAll.Description := Channels."Data Extra 1";
                        POSInfocodeTmpAll."Input Required" := ComissionSalesGroup."FSN Require Input";
                        POSInfocodeTmpAll.INSERT;
                    END;
                UNTIL Channels.NEXT = 0;
        END;

        IF POSInfocodeTmpAll.FIND('-') THEN BEGIN
            POSInfocodeTmpAll.INIT;
            POSInfocodeTmpAll.Code := '.';
            POSInfocodeTmpAll.Description := lTxt3;
            POSInfocodeTmpAll."Input Required" := FALSE;
            POSInfocodeTmpAll.INSERT;
        END;
        IF POSInfocodeTmpStaff.FIND('-') THEN BEGIN
            POSInfocodeTmpStaff.INIT;
            POSInfocodeTmpStaff.Code := '.';
            POSInfocodeTmpStaff.Description := lTxt3;
            POSInfocodeTmpStaff."Input Required" := FALSE;
            POSInfocodeTmpStaff.INSERT;
        END;
    end;

    procedure ClearTablesTmp()
    begin
        POSInfocodeTmpAll.Reset();
        POSInfocodeTmpAll.DeleteAll();
        Clear(POSInfocodeTmpAll);
        POSInfocodeTmpStaff.Reset();
        POSInfocodeTmpStaff.DeleteAll();
        Clear(POSInfocodeTmpStaff);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Controller", 'OnPOSCommand', '', true, true)]
    local procedure "EPOS Controler_OnPOSCommand"
    (
        var ActivePanel: Record "LSC POS Panel";
        var PosMenuLine: Record "LSC POS Menu Line"
    )
    var
        deliverOr: Record "LSC Delivery Order";
        FSNDeliveryFunct: Codeunit "FSN Delivery Functions Extend";
        storeT: Record "LSC Store";
        ChangeMade: Option OrderLines,OrderType,Address,Cancel,OrderTime,Restaurant,RestAddr;
        pContactTMP: Record "Contact" temporary;
        Message: Text[250];
        pBoolInExit: Boolean;
        PageDeliveryTakeOrder: Page "FSN Take Order CC";
        MenuLine: Record "LSC POS Menu Line";
        STORE: Code[20];
    begin

        if PosMenuLine.Command = 'DEL-TAKEORDFUNC' then begin
            case PosMenuLine.Parameter of
                'TYPE-HOME':
                    DeliveryType := DeliveryType::Home;
                'TYPE-TAKEOUT':
                    DeliveryType := DeliveryType::Takeaway;
                'TYPE-OTHER':
                    DeliveryType := DeliveryType::Other;
                'TYPE-WORK':
                    DeliveryType := DeliveryType::Work;
            /*'TIME-CHANGE-FSN':
                ShowSelectedOrder;*/
            end;
            ProcessInputOnSelectingOrderOnOrderTaking;

            /* IF (STATE = STATE::Edit) and (PosMenuLine.Parameter = 'TIME-CHANGE') then begin
                 PosMenuLine.Processed := true;
                 PosMenuLine.modify;
                 ShowSelectedOrder;
             end;

             IF (STATE = STATE::CreateNew) and (PosMenuLine.Parameter = 'TIME-CHANGE') then begin
                 if deliverOr.Get(POSSESSION.GetValue('CURRORDER')) then begin
                     IF (DeliveryOrder."Order Date" <> 0D) or (DeliveryOrder."Contact Pickup Time" <> 0T) THEN BEGIN
                         PosMenuLine.Processed := true;
                         PosMenuLine.modify;
                         ShowSelectedOrder;
                     end;
                 end;
             end;*/
        end;
        //Hace cambio de sucursal en pedido call
        IF PosMenuLine.Command = 'DEL-TAKEORDSELREST' THEN begin
            if deliverOr.Get(POSSESSION.GetValue('CURRORDER')) then begin
                if deliverOr."Call Cent. Web Service Status" in [deliverOr."Call Cent. Web Service Status"::"New-Not Confirmed", deliverOr."Call Cent. Web Service Status"::"New-Not Sent"] then begin
                    //IF FSNDeliveryFunct.MGTCheckChangeAllowed(ChangeMade::Restaurant, deliverOr, pContactTMP, Message, pBoolInExit) then begin
                    FSNDeliveryFunct.ChangeStore(deliverOr."Order No.", PosMenuLine.Parameter, 1);
                    DeliveryOrderManagement.ChangeRestaurant(PosMenuLine."Key No.", PosMenuLine.Parameter);
                    DeliveryOrderManagement.LoadContext(false);
                    PosMenuLine.Processed := true;
                    PosMenuLine.modify;
                    //end;
                end;
            end else begin
                IF PosMenuLine."Menu ID" IN ['#DEL-ORDER-MENUREST2', '#DEL-ORDER-MENUREST3'] then begin
                    STORE := POSSESSION.GetValue('<#XLASTNEXTSTORE>');
                    MenuLine.Reset();
                    MenuLine.SetRange("Profile ID", '#FSN-CC');
                    MenuLine.SetFilter("Menu ID", '<>%1', '#DEL-ORDER-MENUREST');
                    MenuLine.SetRange(Command, 'DEL-TAKEORDSELREST');
                    MenuLine.SetRange(Parameter, STORE);
                    if MenuLine.Find('-') then begin
                        EPosCtrl.SetButtonHighlighted(MenuLine."Menu ID", MenuLine."Key No.", false);
                        EPosCtrl.SetButtonHighlighted(PosMenuLine."Menu ID", PosMenuLine."Key No.", true);
                    end;
                end;
            end;
        end;

        /*deliverOr.Reset();
        if deliverOr.Get(POSSESSION.GetValue('CURRORDER')) then begin
            if FSNDeliveryFunct.MGTCheckChangeAllowed(ChangeMade::Restaurant, deliverOr, pContactTMP, Message, pBoolInExit) then begin
                PosMenuLine.Processed := true;
                PosMenuLine.modify;
            end;
        end;*/

        //Hace cambio de sucursal en pedido call
        /*IF PosMenuLine.Command = 'DEL-TAKEORDSELREST' THEN begin
            if deliverOr.Get(POSSESSION.GetValue('CURRORDER')) then begin
                if deliverOr."Call Cent. Web Service Status" in [deliverOr."Call Cent. Web Service Status"::"New-Not Confirmed", deliverOr."Call Cent. Web Service Status"::"New-Not Sent"] then begin
                    PosMenuLine.Processed := true;
                    PosMenuLine.modify;
                    FSNDeliveryFunct.ChangeStore(deliverOr."Order No.", PosMenuLine.Parameter, 1);
                    if storeT.Get(PosMenuLine.Parameter) then
                        POSSession.SetValue('DEL-RestName', PosMenuLine.Parameter + '-' + storeT.Name);
                end;
            end else begin
                if storeT.Get(PosMenuLine.Parameter) then
                    POSSession.SetValue('DEL-RestName', PosMenuLine.Parameter + '-' + storeT.Name);
            end;
            deliverOr.Reset();
            if deliverOr.Get(POSSESSION.GetValue('CURRORDER')) then begin
                if FSNDeliveryFunct.MGTCheckChangeAllowed(ChangeMade::Restaurant, deliverOr, pContactTMP, Message, pBoolInExit) then begin
                    PosMenuLine.Processed := true;
                    PosMenuLine.modify;
                end;
            end;
        end;*/

    end;

    [EventSubscriber(ObjectType::Table, Database::"LSC POS Trans. Line", 'OnAfterVoidLine', '', true, true)]
    local procedure "LSC POS Trans. Line_OnAfterVoidLine"(var Rec: Record "LSC POS Trans. Line")
    var
        PosInfocode: Record "LSC POS Trans. Infocode Entry";
        WebS: Record "FSN WebServiceTable";
    begin
        PosInfocode.Reset();
        PosInfocode.SetRange("Receipt No.", Rec."Receipt No.");
        PosInfocode.SetRange("Transaction Type", PosInfocode."Transaction Type"::"Payment Entry");
        PosInfocode.SetRange("Line No.", Rec."Line No.");
        if PosInfocode.Find('-') then
            repeat
                PosInfocode.Delete();
            until PosInfocode.Next() = 0;
    end;


    /*[EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Controller", 'OnBeforeContextUpdate', '', true, true)]
    local procedure "EPOS Controler_OnBeforeContextUpdate"()
    var
        EPOSControlInterface: Codeunit "LSC POS Control Interface";
    begin
        if DeliveryOrder.Get(POSSESSION.GetValue('CURRORDER')) then
            if FSNSalesChannel.Get(DeliveryOrder."Order No.") then
                EPOSControlInterface.SetValue('#fsnSalesChannel', FSNSalesChannel.SalesChannel)
            else
                EPOSControlInterface.SetValue('#fsnSalesChannel', '');
    end;*/

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Controller", 'OnKeyboardResult', '', true, true)]
    local procedure "EPOS Controler_OnKeyboardResult"
   (
       payload: Text;
       inputValue: Text;
       resultOK: Boolean;
       var processed: Boolean
   )
    var
        Done: Boolean;
    begin
        if resultOK then
            if (payload = 'SCHANNEL_TK') and (inputValue <> '') then begin
                PosSetup.RESET;
                PosSetup.SETCURRENTKEY(Type, "Line Type", "From Date", "Value No.", "Line No.", "Store No.");
                PosSetup.SETRANGE(PosSetup.Type, PosSetup.Type::CallCenter);
                PosSetup.SETRANGE(PosSetup."Line Type", PosSetup."Line Type"::Parameter);
                PosSetup.SETRANGE(PosSetup."From Date", 0D);
                PosSetup.SETRANGE(PosSetup."Value No.", 'CHANNELTYPE');
                IF PosSetup.FIND('-') THEN
                    REPEAT
                        IF (STRPOS(PosSetup."Data Extra 2", (COPYSTR(inputValue, 1, STRPOS(inputValue, '-') - 1))) > 0) AND PosSetup.Active THEN BEGIN
                            SaveChannel(DeliveryOrder."Order No.", FORMAT(PosSetup."Line No."), PosSetup."Data Extra 1", FALSE, inputValue);
                            Done := true;
                        end;
                    until (PosSetup.Next = 0) or Done;
                if not Done or FSNSalesChannel.Get(DeliveryOrder."Order No.") then
                    ShowChannelByType(true);

            end;
    end;

    //HOSPITALITY
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC Hospitality POS Startup", 'OnAfterExecuteCommand', '', true, true)]
    local procedure "LSC Hospitality POS Startup_OnAfterExecuteCommand"
    (
        MenuLine: Record "LSC POS Menu Line";
        CurrentReceipt: Code[20];
        var HospitalityTypeTemp: Record "LSC Hospitality Type";
        ActiveDiningArea: Record "LSC Dining Area";
        ActiveServiceFlow: Record "LSC Hospitality Service Flow"
    )
    var
        POSterminal_l: Record "LSC POS Terminal";
    begin
        IF POSterminal_l.Get(POSSESSION.TerminalNo()) then
            if (MenuLine.Command = 'HOSP-OPEN-POS-DIR') and (POSSESSION.GetValue('CURRORDER') = 'NEWSALE') then begin
                POSSESSION.SetValue('SALESTYPE', POSterminal_l."Default Sales Type");
                POSSESSION.DeleteValue('PREVENT_NORMSALE');
            end;
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
        HospPOSStart: Codeunit "LSC Hospitality POS Startup";
        SelReceiptNo: Code[50];
        SelectedReceiptNo: Code[50];
        EPosCtrl: Codeunit "LSC POS Control Interface";
        HospOrderKotStatus: Record "LSC Hosp. Order KOT Status";
        DelFunc: Codeunit "LSC Delivery Functions";
        HospitalityTypeTemp2: Record "LSC Hospitality Type";
        _exit: Boolean;
        orderNo: Code[20];
        RetailSetup_l: Record "LSC Retail Setup";
    begin
        if MenuLine.Command = 'DELEDIT' then begin
            HospitalityTypeTemp2.Reset();
            HospitalityTypeTemp2.SetRange("Restaurant No.", HospitalityTypeTemp."Restaurant No.");
            HospitalityTypeTemp2.SetRange("Layout View", HospitalityTypeTemp2."Layout View"::Delivery);
            if HospitalityTypeTemp2.Find('-') then
                MenuLine.Command := 'HOSP-ORDEREDIT';
        end;
        //NEW PEOCESS CALL
        RetailSetup_l.Get();
        if RetailSetup_l."FSN Is Local Receipt" and (RetailSetup_l."FSN Last Slipt No." <> '') then begin
            if MenuLine.Command = 'HOSP-ORDEREDIT' then begin
                IsHandled := true;
                if EPosCtrl.ActiveDataGrid = '' then begin
                    //HospPOSStart.ErrorBeep(Text131, true);
                    exit;
                end;
                SelReceiptNo := EPosCtrl.GetDataGridKeyValue(EPosCtrl.ActiveDataGrid);
                if SelReceiptNo = '' then begin
                    //ErrorBeep(Text131, true);
                    exit;
                end;
            end;
        end;
    end;

    procedure GetReceipt(): Code[20]
    var
        myInt: Integer;
    begin
        exit(GlobalReceipt);
    end;

    procedure SetReceipt(Receipt: Code[20])
    var
        myInt: Integer;
    begin
        GlobalReceipt := Receipt;
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
        POSTransaction_l: Record "LSC POS Transaction";
        WebTable: Record "FSN WebServiceTable";
        PG: Page "FSN PAQUETERIA";
        ValCustomer: Record Customer;
        ComtactV: Record Contact;
        TEXT005: Label 'Debe definir Cliente';
        TEXT006: Label 'Cliente debe de tener Numero de Telefono';
        CallFunction: Codeunit "FSN Delivery Functions Extend";
        Deliveripage: Record "LSC Delivery Order";
        RetailSetup_l: Record "LSC Retail Setup";
        POSTransCodeunit: Codeunit "LSC POS Transaction";
        XMLRequest: Text;
        XMLResponse: Text;
        RequestID: Text[50];
        MsgResult: Text;
        POSMenuLineTemp: Record "LSC POS Menu Line" temporary;
        Processed: Boolean;
        FSNUtility: Codeunit "FSN Utility";
        Log: Record "FSN Change Log Transaction";
        Text010: Label 'Desea crear paqueteria a la sala: %1';
        Text011: Label 'Debe agregar primero la media de pago';
    begin
        RetailSetup_l.Get();
        if PosEvent.ActivePanel = '#POS' THEN
            if PosEvent.EventType in [
                Enum::"LSC POS Event Type"::DATAROWDOUBLECLICK
            ] then begin
                POSLines.GetCurrentLine(POSLine_l);
                if (POSLine_l."Entry Type" = POSLine_l."Entry Type"::Item) AND
                    (POSLine_l."Entry Status" = POSLine_l."Entry Status"::" ") THEN begin
                    GlobalParametro();
                    if GlobalParametroPQ.Valor = POSLine_l.Number then begin
                        if (POSSESSION.GetValue('Balance') in ['0.00', '0']) then begin
                            Deliveripage.Reset();
                            if Deliveripage.Get(POSLine_l."Receipt No.") then begin
                                PG.SETGLOBALVALUE(Deliveripage);
                                PG.SetRecord(Deliveripage);
                                Commit();
                                if PG.RunModal() = Action::OK then begin
                                    if RetailSetup_l."FSN Is Local Receipt" and (RetailSetup_l."FSN Last Slipt No." <> '') then begin
                                        If validateinfo(Deliveripage) then begin
                                            IF not CONFIRM(STRSUBSTNO(Text010, Deliveripage."Restaurant No.")) THEN
                                                exit;
                                        end else
                                            exit;
                                        IF POSSESSION.GetValue('GUIAC807') = '' then begin
                                            if CallFunction.ValidatePaqueteria(Deliveripage) then begin
                                                RequestID := 'SENPQC807';//manda Formulario
                                                MsgResult := Format(Deliveripage."General Status");
                                                XMLRequest := Deliveripage."Order No.";
                                                FSNUtility.InvokeGlobalChannel(XMLRequest, XMLResponse, RequestID, PosMenuLineTemp, Processed, MsgResult);

                                                IF Log.FIND('+') THEN
                                                    Log."Entry No." := Log."Entry No." + 1;
                                                if Log."Entry No." = 0 then begin
                                                    Log."Entry No." := 1;
                                                end;
                                                Log."Receipt No." := Deliveripage."Order No.";
                                                IF STRLEN(Deliveripage."Phone No.") > 10 THEN
                                                    Log."Phone No." := COPYSTR(Deliveripage."Phone No.", STRLEN(Deliveripage."Phone No.") - 10, 10)
                                                ELSE
                                                    Log."Phone No." := Deliveripage."Phone No.";
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
                            END;
                        END else
                            Message(Text011);
                    end;
                end;
            end;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Transaction Events", 'OnBeforeGetContext', '', true, true)]
    local procedure "LSC POS Transaction Events_OnBeforeGetContext"
    (
        var POSTransaction: Record "LSC POS Transaction";
        var POSTransLine: Record "LSC POS Trans. Line";
        var CurrInput: Text
    )
    begin
        POSTransaction."Member Card No." := '';
    end;

}
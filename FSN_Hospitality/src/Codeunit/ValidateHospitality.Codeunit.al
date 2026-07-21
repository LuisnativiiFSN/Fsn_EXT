codeunit 50098 "FSN Validate Hospitality"
{
    TableNo = "LSC Scheduler Job Header";

    trigger OnRun()
    begin
        GlobalRec := Rec;
        if PosTransGlobal.Get(GlobalRec.Text) then;
        case Code of
            'FSNDELPOST':
                PostDeliverySale(GlobalRec.Text);
            'TIPOLOGIA0':
                begin
                    ApplyTipology0();
                end;
            'POSTEDDELIVERY':
                ChangePosDelivery();
            'VALORDERPROSESS':
                begin
                    ValOrderProcess();
                end;
            'DAFECOMM_BC':
                begin
                    ReconfDaf();
                end;
            'DELPREFA_BC':
                DelecPrefactura();
            'DAF-ERROR':
                DAF();
            'RESTPASSWORD':
                ResetPassword();
            'CONFIRMDAFSALA':
                ConfirmDAFSala();
            'MENSUALDTE':
                CertMes();
            else
                JobSendFinalOrder;

        end;

    end;

    var
        EPosCtrl: Codeunit "LSC POS Control Interface";
        POSTransactionBK: Record "LSC POS Transaction";
        POSSetupExtBK: Record "FSN POS Setup Extend";
        CCPOSTermBK: Record "LSC CC POS Term. Assignm.";
        CSWebServiceTableBK: Record "FSN WebServiceTable";
        DeliveryOrderBK: Record "LSC Delivery Order";
        PosTransGlobal: Record "LSC POS Transaction";
        GlobalRec: Record "LSC Scheduler Job Header";
        OfflineCCWSClient: Codeunit "LSC Offl. CC Web Serv. Client";
        WSFunc: Codeunit "LSC WS Functions";
        WebServiceSetup: Record "LSC Web Service Setup";
        WSRequest: Record "LSC WS Request";
        WebServicesConn: Codeunit "LSC Web Services Connection";
        PosFuncProfile: Record "LSC POS Func. Profile";
        XMLDomMgt: Codeunit "LSC XML DOM Mgt.";
        PosTransGlobalC: Codeunit "LSC POS Transaction";
        POSTransLineTmp: Record "LSC POS Trans. Line" temporary;

    local procedure CertMes()
    var
        transaction, transaction_tmp : Record "LSC Transaction Header";
        dte: Record "FSN DTE Transaction Header";
        dteRevert: Record "FSN DTE Transaction Header";
        session: Codeunit "LSC POS Session";
        ElectronicInvoiceTest: Codeunit "FSN Electronic Invoice";
        transRetreived: Record "LSC Transaction Header";
        NextStep: Boolean;
        TransHeader: Record "LSC Transaction Header" temporary;
        DTEHeader: Record "FSN DTE Transaction Header";
        POSSESION: Codeunit "LSC POS Session";
        RetailSetup: Record "LSC Retail Setup";
    begin
        GLOBALLANGUAGE(2058);
        RetailSetup.Get();
        POSSESION.SetValue('DTEJOB', 'TRUE');
        if posSession.StoreNo() = '' then
            POSSESION.SetStore(RetailSetup."Local Store No.");
        POSSESION.SetValue('PAGEDTE', 'TRUE');
        POSSESION.SetValue('DTEMESSAGE', 'TRUE');
        TransHeader.DeleteAll();
        //? this calculate the initial date of current month
        transaction.SetRange("Date", CALCDATE('<-CM>', TODAY), Today);
        transaction.SetFilter("Refund Receipt No.", '= %1', '');
        transaction.SetRange("Entry Status", 0);
        transaction.SetRange("Transaction Type", transaction."Transaction Type"::"Sales");
        transaction.SetFilter("FSN Document Type", '%1|%2|%3', transaction."FSN Document Type"::Factura, transaction."FSN Document Type"::"Nota Credito", transaction."FSN Document Type"::"Credito Fiscal");
        transaction.SetRange("FSN Fiscal Serie", '');
        if transaction.Find('-') then
            repeat
                NextStep := true;
                if (transaction."FSN Document Type" in [transaction."FSN Document Type"::"Credito Fiscal", transaction."FSN Document Type"::Factura]) and (transaction."Refund Receipt No." <> '') then
                    NextStep := false;
                transRetreived.Reset();
                transRetreived.SetRange("Receipt No.", transaction."Retrieved from Receipt No.");
                transRetreived.SetRange("Entry Status", 0);
                transRetreived.SetRange("Transaction Type", transRetreived."Transaction Type"::"Sales");
                if (transaction."FSN Document Type" = transaction."FSN Document Type"::"Nota Credito") then
                    if transRetreived.FindFirst() then
                        if transRetreived."FSN Fiscal Serie" <> '' then
                            NextStep := true
                        else
                            if not dteRevert.Get(transRetreived."Store No.", transRetreived."POS Terminal No.", transRetreived."Transaction No.") then
                                NextStep := false;

                dte.Reset();
                dte.SetRange("Store No.", transaction."Store No.");
                dte.SetRange("POS Terminal No.", transaction."POS Terminal No.");
                dte.SetRange("Transaction No.", transaction."Transaction No.");
                if NextStep then
                    if not dte.FindFirst() then begin
                        if (transaction."Sale Is Return Sale") and (transaction."FSN Document Type" <> transaction."FSN Document Type"::"Nota Credito") then begin
                            ElectronicInvoiceTest.GenerateAndSendAnulation(transaction)
                        end else begin
                            if POSSESION.TerminalNo() <> transaction."POS Terminal No." then
                                POSSESION.SetTerminal(transaction."POS Terminal No.");
                            ElectronicInvoiceTest.GenerateAndSendInvoice(transaction);
                        end;
                    end else begin
                        if transaction."Sale Is Return Sale" and (transaction."FSN Document Type" <> transaction."FSN Document Type"::"Nota Credito") then begin
                            transaction_tmp.SetRange("Receipt No.", transaction."Retrieved from Receipt No.");
                            transaction_tmp.setRange("Store No.", transaction."Store No.");
                            transaction_tmp.setRange("POS Terminal No.", transaction."POS Terminal No.");
                            if transaction_tmp.FindFirst() then begin
                                dte.Reset();
                                dte.SetRange("Store No.", transaction."Store No.");
                                dte.SetRange("POS Terminal No.", transaction."POS Terminal No.");
                                dte.SetRange("Transaction No.", transaction."Transaction No.");
                                dte.SetRange("Status", dte.Status::Anulled);
                                if not dte.FindFirst() then begin
                                    if (transaction."Sale Is Return Sale") and (transaction."FSN Document Type" <> transaction."FSN Document Type"::"Nota Credito") then begin
                                        ElectronicInvoiceTest.GenerateAndSendAnulation(transaction)
                                    end else begin
                                        if POSSESION.TerminalNo() <> transaction."POS Terminal No." then
                                            POSSESION.SetTerminal(transaction."POS Terminal No.");
                                        ElectronicInvoiceTest.GenerateAndSendInvoice(transaction);
                                    end;
                                end;
                            end;
                        end
                    end;
            until transaction.Next() = 0;
        POSSESION.SetValue('PAGEDTE', '');
        POSSESION.SetValue('DTEMESSAGE', '');
        POSSESION.SetValue('DTEJOB', '');
        Commit();
    end;

    procedure ResetPassword()
    var
        Staff: Record "LSC Staff";
        FechaMedia, FechaUltima : Date;
        trans: Record "LSC Trans. Sales Entry Status";

    begin
        FechaMedia := CALCDATE('<-CM+14D>', Today);
        FechaUltima := CALCDATE('<CM>', Today);
        if Today in [FechaMedia, FechaUltima] then begin
            Staff.Reset();
            Staff.SetRange(Blocked, false);
            Staff.SetFilter(ID, '<>%1&%2', '16879', '15837');
            if Staff.Find('-') then begin
                repeat
                    Staff."Change Password" := true;
                    staff.Modify(true);
                    Commit();
                until Staff.Next() = 0;
            end;
        end;
    end;

    procedure ChangePosDelivery()
    var
        DeliveryOrder: Record "LSC Delivery Order";
        TransHeader: Record "LSC Transaction Header";
        SheduleJobHeaderTemp: Record "LSC Scheduler Job Header" temporary;
        Hospitality: Codeunit "FSN Validate Hospitality";
    begin
        DeliveryOrder.Reset();
        DeliveryOrder.SetRange("Order Date", CALCDATE('<-CM>', TODAY), Today);
        DeliveryOrder.SetRange("General Status", DeliveryOrder."General Status"::"In Process");
        if DeliveryOrder.Find('-') then begin
            repeat
                TransHeader.Reset();
                TransHeader.SetRange("Receipt No.", DeliveryOrder."Order No.");
                if TransHeader.Find('-') then begin
                    SheduleJobHeaderTemp.INIT;
                    SheduleJobHeaderTemp.Code := 'FSNDELPOST';
                    SheduleJobHeaderTemp.Text := FORMAT(DeliveryOrder."Order No.");
                    COMMIT;
                    Hospitality.RUN(SheduleJobHeaderTemp);
                end;
            until DeliveryOrder.Next() = 0;
        end;
    end;

    /// <summary>
    /// DAF.
    /// </summary>
    procedure DAF()
    var
        PostedDelOrder: Record "LSC Posted Delivery Order";
        DelOrder: Record "LSC Delivery Order";
        DeliveryTrip: Record "FSN Delivery Trip";
        DATTime: DateTime;
    begin
        DATTime := CreateDateTime(Today, 0T);
        DeliveryTrip.Reset();
        DeliveryTrip.SetRange("General Status", DeliveryTrip."General Status"::ERROR);
        DeliveryTrip.SetRange("Trip. Status", DeliveryTrip."Trip. Status"::"No Started");
        DeliveryTrip.SetFilter("Create Time", '>=%1', DATTime);
        if DeliveryTrip.Find('-') then begin
            repeat
                if DeliveryTrip."POS Terminal No." = '' then
                    if PostedDelOrder.Get(DeliveryTrip."Order No.") then begin
                        DeliveryTrip."POS Terminal No." := PostedDelOrder."POS Terminal No.";
                        DeliveryTrip.Modify(true);
                    end;
                EcommerceDAF(DeliveryTrip."Order No.", false);
            until DeliveryTrip.Next() = 0;
        end;
    end;

    procedure ReconfDaf()
    var
        myInt: Integer;
        Ws: Record "FSN WebServiceTable";
        DelOrders: Record "LSC Delivery Order";
        PDelTrip: Record "FSN Delivery Trip";
    begin
        ws.Reset();
        Ws.SetRange("WS Request", 'SEND_POSTRANS_BACKUP');
        WS.SetRange(Date, Today);
        WS.SetRange("Order Type", WS."Order Type"::Delivery);
        if Ws.Find('-') then begin
            repeat
                if PDelTrip.Get(Ws.LastSlipNo) then begin
                    if PDelTrip."General Status" = PDelTrip."General Status"::InProcess then
                        EcommerceDAF(PDelTrip."Order No.", false);
                end else begin
                    if DelOrders.Get(ws.LastSlipNo) then begin
                        if DelOrders."General Status" = DelOrders."General Status"::"In Process" then
                            if DelOrders."Call Cent. Web Service Status" in
                        [DelOrders."Call Cent. Web Service Status"::"New-Sent",
                        DelOrders."Call Cent. Web Service Status"::"Changed-Sent"] then begin
                                EcommerceDAF(DelOrders."Order No.", true);
                            end;
                    end;
                end;
            until ws.next() = 0;
        end;
    end;

    procedure ConfirmDAF()
    var
        ws: Record "FSN WebServiceTable";
        POSGUI: Codeunit "LSC POS GUI";
        XMLRequest: Text;
        XMLResponse: Text;
        RequestID: Text[50];
        PosMenuLineTemp: Record "LSC POS Menu Line" Temporary;
        Processed: Boolean;
        MsgResult: Text;
        FSNUtility: Codeunit "FSN Utility";
        POStDeliveryOrder: Record "LSC Posted Delivery Order";
        DelOrder: Record "LSC Delivery Order";//call155
    begin
        ws.Reset();
        ws.SetRange(Date, Today());
        ws.SetRange("WS Request", '');
        ws.SetRange("Status WS", ws."Status WS"::Pending);
        if ws.FindSet() then
            repeat
                if POStDeliveryOrder.Get(ws.LastSlipNo) then begin
                    DelOrder.TransferFields(POStDeliveryOrder);
                    DelOrder.Insert();
                    if POSSESSION.TerminalNo() = '' then
                        POSSESSION.SetTerminal(POStDeliveryOrder."POS Terminal No.");
                end;

                RequestID := 'DEL-TRANSFSN';//Crea tabla de delivery trip a DAF
                XMLRequest := ws.LastSlipNo;
                MsgResult := '';
                FSNUtility.InvokeGlobalChannel(XMLRequest, XMLResponse, RequestID, PosMenuLineTemp, Processed, MsgResult);
                IF MsgResult = 'TRUE' then begin
                    WS."Status WS" := WS."Status WS"::Send;
                    WS.Modify();
                    if POStDeliveryOrder.Get(ws.LastSlipNo) then begin
                        if DelOrder.Get(ws.LastSlipNo) then
                            DelOrder.Delete(true);
                    end;
                end;
            until ws.Next() = 0;
    end;

    procedure ConfirmDAFSala()
    var
        ws: Record "FSN WebServiceTable";
        POSGUI: Codeunit "LSC POS GUI";
        XMLRequest: Text;
        XMLResponse: Text;
        RequestID: Text[50];
        PosMenuLineTemp: Record "LSC POS Menu Line" Temporary;
        Processed: Boolean;
        MsgResult: Text;
        FSNUtility: Codeunit "FSN Utility";
        PostedDelOrder: Record "LSC Posted Delivery Order";
    begin
        PostedDelOrder.Reset();
        PostedDelOrder.SetRange("Posting Date", Today);
        PostedDelOrder.SetRange(Delivered, false);
        PostedDelOrder.SetRange("General Status", PostedDelOrder."General Status"::Completed);
        if PostedDelOrder.FindSet() then
            repeat
                RequestID := 'DAF-TEST';//Crea tabla de delivery trip a DAF
                XMLRequest := PostedDelOrder."Order No.";
                MsgResult := '';
                FSNUtility.InvokeGlobalChannel(XMLRequest, XMLResponse, RequestID, PosMenuLineTemp, Processed, MsgResult);
                IF MsgResult = 'TRUE' then begin
                    PostedDelOrder.Delivered := true;
                    PostedDelOrder.Modify();
                end;
            until PostedDelOrder.Next() = 0;
    end;

    procedure MensualDAf()
    var
        ws: Record "FSN WebServiceTable";
        POSGUI: Codeunit "LSC POS GUI";
        XMLRequest: Text;
        XMLResponse: Text;
        RequestID: Text[50];
        PosMenuLineTemp: Record "LSC POS Menu Line" Temporary;
        Processed: Boolean;
        MsgResult: Text;
        FSNUtility: Codeunit "FSN Utility";
        PostedDelOrder: Record "LSC Posted Delivery Order";
    begin
        PostedDelOrder.Reset();
        PostedDelOrder.SetFilter("Posting Date", '>=%1', CALCDATE('<-CM>', Today));
        PostedDelOrder.SetRange(Delivered, false);
        PostedDelOrder.SetRange("General Status", PostedDelOrder."General Status"::Completed);
        if PostedDelOrder.FindSet() then
            repeat
                RequestID := 'DAF-TEST';//Crea tabla de delivery trip a DAF
                XMLRequest := PostedDelOrder."Order No.";
                MsgResult := '';
                FSNUtility.InvokeGlobalChannel(XMLRequest, XMLResponse, RequestID, PosMenuLineTemp, Processed, MsgResult);
                IF MsgResult = 'TRUE' then begin
                    PostedDelOrder.Delivered := true;
                    PostedDelOrder.Modify();
                end;
            until PostedDelOrder.Next() = 0;
    end;

    procedure EcommerceDAF(Order: Code[20]; New: Boolean)
    var
        myInt: Integer;
        storeLink: record "FSN Store Link";
        lat: Decimal;
        lon: Decimal;
        storeLink_tmp2: record "FSN Store Link" temporary;
        StoreLink2: Record "FSN Store Link";
        km: Decimal;
        Delstret: Record "LSC Delivery Street";
        km2: Decimal;
        store: Record "LSC Store";
        store_tmp, store_tmp2 : Record "LSC Store" temporary;
        OrderType: Option Home,Work,Other,Takeout;
        DelContac: Record Contact;
        DeliveryOrder: Record "LSC Delivery Order";
        DeliveryTrip: Record "FSN Delivery Trip";
        POSGUI: Codeunit "LSC POS GUI";
        XMLRequest: Text;
        XMLResponse: Text;
        RequestID: Text[50];
        PosMenuLineTemp: Record "LSC POS Menu Line" Temporary;
        Processed: Boolean;
        MsgResult: Text;
        FSNUtility: Codeunit "FSN Utility";
    begin
        if New then begin
            POSSESSION.SetValue('DEL-PickupDate', Format(Today));
            POSSESSION.SetValue('DEL-PickupTime', format(Time));
            RequestID := 'DEL-TRANSFSN';//Crea tabla de delivery trip a DAF
            XMLRequest := Order;
            FSNUtility.InvokeGlobalChannel(XMLRequest, XMLResponse, RequestID, PosMenuLineTemp, Processed, MsgResult);
        end else begin
            RequestID := 'RENCONF_DAF';//manda a DAF
            XMLRequest := Order;
            FSNUtility.InvokeGlobalChannel(XMLRequest, XMLResponse, RequestID, PosMenuLineTemp, Processed, MsgResult);
        end;
    end;

    procedure DelecPrefactura()
    var
        myInt: Integer;
        Ws: Record "FSN WebServiceTable";
        Tran: Text;
        ValParameter: Record "FSN Parameter";
        RetailSetup: Record "LSC Retail Setup";
        DelOrders: Record "LSC Delivery Order";
        POStransac: Record "LSC POS Transaction";
    begin
        ws.Reset();
        Ws.SetRange("Status WS", ws."Status WS"::InProcess);
        Ws.SetRange("WS Request", 'SEND_POSTRANS_BACKUP_BC');
        if Ws.Find('-') then begin
            repeat
                RetailSetup.Get();
                DelOrders.Reset();
                if DelOrders.Get(ws.LastSlipNo) then
                    DelOrders.Delete(true);
                POStransac.Reset();
                if POStransac.Get(ws.LastSlipNo) then
                    POStransac.Delete(true);
            until ws.next() = 0;
        end;
    end;

    procedure ValOrderProcess()
    var
        POSTRANS: Record "LSC POS Transaction";
        DELORDER: Record "LSC Delivery Order";
        SqlConnection: DotNet SqlConnection;
        SqlCommand: DotNet SqlCommand;
        SqlDataReader: DotNet SqlDataReader;
        ConnectionString: Text[125];
        SqlString: Text;
        DisLocation: Record "LSC Distribution Location";
        lTextConn: Label 'Data Source=%1;Initial Catalog=%2;Integrated Security=false; User ID=%3;Password=%4;';
        lTextSimbol: Label '''''';
        Receipt: code[20];
        Tran: Text;
        ValParameter: Record "FSN Parameter";
        RetailSetup: Record "LSC Retail Setup";
    begin
        RetailSetup.Get();
        if DisLocation.GET(RetailSetup."Local Store No.") then begin
            ConnectionString := STRSUBSTNO(lTextConn, DisLocation."Db Server Name", DisLocation."Db. Path && Name", DisLocation."User ID", DisLocation.Password);
            SqlConnection := SqlConnection.SqlConnection(ConnectionString);

            SqlString := '	DELETE [DBTIENDA].[dbo].[FASANI$LSC POS Transaction$a397324a-67fe-4557-aefb-aa375b30dbdf] ' +
                            'WHERE [Receipt No_] IN ( ' +
                            '   SELECT [Order No_] FROM [DBTIENDA].[dbo].[FASANI$LSC Posted Delivery Order$5ecfc871-5d82-43f1-9c54-59685e82318d] ' +
                            '   WHERE [Order No_] IN ( ' +
                            '       SELECT a.[Receipt No_] ' +
                            '       FROM [DBTIENDA].[dbo].[FASANI$LSC POS Transaction$a397324a-67fe-4557-aefb-aa375b30dbdf] as a ' +
                            '       left join [DBTIENDA].[dbo].[FASANI$LSC POS Transaction$5ecfc871-5d82-43f1-9c54-59685e82318d] as c ' +
                            '       on a.[Receipt No_] = c.[Receipt No_] ' +
                            '       WHERE c.[Receipt No_] IS NULL AND EXISTS (SELECT [Receipt No_] FROM [DBTIENDA].[dbo].[FASANI$LSC Transaction Header$5ecfc871-5d82-43f1-9c54-59685e82318d] AS B ' +
                            '       WHERE B.[Receipt No_] = A.[Receipt No_]) ' +
                            '   ) ' +
                            ')';

            SqlConnection.Open();
            SqlCommand := SqlConnection.CreateCommand();
            SqlCommand.CommandText := SqlString;

            SqlDataReader := SqlCommand.ExecuteReader();
            IF SqlDataReader.Read() THEN begin
                Tran := SqlDataReader.GetString(0);
                Message(Tran);
            end;
            SqlConnection.Close();
        end;
    end;

    /// <summary>
    /// Apply Tipology 0 to the order
    /// </summary>
    procedure ApplyTipology0()
    var
        PostedDelOrder: Record "LSC Posted Delivery Order";
        TransactionHeader: Record "LSC Transaction Header";
        POSTransaction: Record "LSC POS Transaction";
        POSTransLine: Record "LSC POS Trans. Line";
        FSNParameter: Record "FSN Parameter";
        POStransC: Codeunit "LSC POS Transaction";
        ePOSControl: Codeunit "LSC POS Control Interface";
        ProcText: Text[1024];
        RecNo: Code[20];
        Band: Boolean;
        lText001: Label 'This order cannot be processed as Typology 0.';
        InfoCodeEntry: Record "LSC Trans. Infocode Entry";
        VoidedLine: Record "LSC POS Voided Trans. Line";
        VoidedInfoCodeEntry: Record "LSC POS Voided Infoc Entry";
        InfoCodeEntryToDelete: Record "LSC POS Trans. Infocode Entry";
    begin
        RecNo := ePOSControl.GetDataGridKeyValue(ePOSControl.ActiveDataGrid());
        if POSTransaction.Get(RecNo) then begin
            Clear(Band);
            FSNParameter.Reset();
            FSNParameter.SetCurrentKey("Grupo", "Codigo");
            FSNParameter.SetRange("Grupo", 'TPVBLOCK');
            if FSNParameter.Find('-') then
                repeat
                    POSTransLine.Reset();
                    POSTransLine.SetCurrentKey("Receipt No.", "Entry Type", "Entry Status");
                    POSTransLine.SetRange("Receipt No.", RecNo);
                    POSTransLine.SetRange("Entry Type", POSTransLine."Entry Type"::Item);
                    POSTransLine.SetRange("Entry Status", POSTransLine."Entry Status"::" ");
                    POStransLine.SetRange("Number", FSNParameter.Codigo);
                    if POSTransLine.FindFirst() then
                        Band := true;
                until FSNParameter.Next() = 0;

            if not Band then begin
                POSTransLine.Reset();
                POSTransLine.SetCurrentKey("Receipt No.", "Entry Type", "Entry Status");
                POSTransLine.SetRange("Receipt No.", RecNo);
                POSTransLine.SetRange("Entry Type", POSTransLine."Entry Type"::Item);
                POSTransLine.SetRange("Entry Status", POSTransLine."Entry Status"::" ");
                if not POSTransLine.Find('-') then
                    Band := true;
            end;

            if not Band then begin
                Error(lText001);
                exit;
            end;

            POStransC.SetPOSTransaction(POSTransaction);
            POStransC.VoidTransaction();

            PostDeliverySale(RecNo);
            if PostedDelOrder.Get(RecNo) then begin
                TransactionHeader.Reset();
                TransactionHeader.SetCurrentKey("Receipt No.");
                TransactionHeader.SetRange(TransactionHeader."Receipt No.", PostedDelOrder."Order No.");
                IF TransactionHeader.FindLast() THEN begin
                    ValInfoTipology(TransactionHeader);
                    VoidedInfoCodeEntry.Reset();
                    VoidedInfoCodeEntry.SetRange("Receipt No.", PostedDelOrder."Order No.");
                    if VoidedInfoCodeEntry.Find('-') then
                        repeat
                            InfoCodeEntry.TransferFields(VoidedInfoCodeEntry);
                            InfoCodeEntry."Transaction No." := TransactionHeader."Transaction No.";
                            InfoCodeEntry."POS Terminal No." := TransactionHeader."POS Terminal No.";
                            InfoCodeEntry.Date := TODAY();
                            InfoCodeEntry.Time := TIME();
                            if not InfoCodeEntry.Insert(true) then
                                InfoCodeEntry.Modify(true);
                        until VoidedInfoCodeEntry.Next() = 0;
                    SendFinalOrderToCC(TransactionHeader, PostedDelOrder."Created at Call Center", ProcText);
                end;
            end;
        end;
    end;

    local procedure ValInfoTipology(TransHeader: Record "LSC Transaction Header")
    var
        myInt: Integer;
        VoidLine: Record "LSC POS Voided Trans. Line";
    begin
        VoidLine.Reset();
        VoidLine.SetRange("Receipt No.", TransHeader."Receipt No.");
        VoidLine.SetRange("Entry Type", VoidLine."Entry Type"::FreeText);
        if VoidLine.Find('-') then
            repeat
                CopylineInfocode(VoidLine, TransHeader)
            until VoidLine.Next() = 0;
    end;

    procedure CopylineInfocode(VoidLine: Record "LSC POS Voided Trans. Line"; TransHeader: Record "LSC Transaction Header")
    var
        myInt: Integer;
        InfoCodeEntry: Record "LSC Trans. Infocode Entry";
    begin
        InfoCodeEntry.Reset();
        InfoCodeEntry.SetRange("Store No.", TransHeader."Store No.");
        InfoCodeEntry.SetRange("POS Terminal No.", TransHeader."POS Terminal No.");
        InfoCodeEntry.SetRange("Transaction No.", TransHeader."Transaction No.");
        InfoCodeEntry.SetRange("Line No.", VoidLine."Line No.");
        if not InfoCodeEntry.FindFirst() then begin
            InfoCodeEntry.INIT;
            InfoCodeEntry."Store No." := VoidLine."Store No.";
            InfoCodeEntry."POS Terminal No." := TransHeader."POS Terminal No.";
            InfoCodeEntry."Transaction No." := TransHeader."Transaction No.";
            InfoCodeEntry."Transaction Type" := 0;
            InfoCodeEntry."Line No." := VoidLine."Line No.";
            InfoCodeEntry.Infocode := 'TEXT';
            InfoCodeEntry.Information := VoidLine.Description;
            InfoCodeEntry.Date := TODAY();
            InfoCodeEntry.Time := TIME();
            InfoCodeEntry."Staff ID" := TransHeader."Staff ID";
            IF NOT InfoCodeEntry.INSERT(TRUE) THEN
                InfoCodeEntry.MODIFY(TRUE);
        end;
    end;

    procedure PostDeliverySale("Receipt No.": Code[20])
    var
        DelOrder: Record "LSC Delivery Order";
        PostedDelOrder: Record "LSC Posted Delivery Order";
        TransactionHeader: Record "LSC Transaction Header";
    begin
        //PostDeliverySale
        if DelOrder.Get("Receipt No.") then begin
            if (DelOrder."General Status" = DelOrder."General Status"::"In Process") or
               (DelOrder."General Status" = DelOrder."General Status"::ERROR)
            then
                DelOrder.Validate("General Status", DelOrder."General Status"::Confirmed);

            PosTransGlobal.CalcFields("Gross Amount");
            PostedDelOrder.Init;
            PostedDelOrder.TransferFields(DelOrder);
            PostedDelOrder."Amount Incl. VAT" := PosTransGlobal."Gross Amount";
            if PosTransGlobal."Entry Status" = PosTransGlobal."Entry Status"::Voided then
                PostedDelOrder."Rest. Web Service Status" := PostedDelOrder."Rest. Web Service Status"::"Cancelled-Not Sent"
            else
                PostedDelOrder."Rest. Web Service Status" := PostedDelOrder."Rest. Web Service Status"::"Finalized-Not Sent";
            PostedDelOrder."Posting Date" := Today;
            PostedDelOrder."Posting Time" := Time;
            if PosTransGlobal."Entry Status" = PosTransGlobal."Entry Status"::Voided then
                PostedDelOrder.Validate("General Status", PostedDelOrder."General Status"::Cancelled)
            else begin
                if DelOrder."Assigned to Driver" then
                    PostedDelOrder.Validate(Delivered, true);
            end;

            TransactionHeader.Reset();
            TransactionHeader.SetCurrentKey("Receipt No.");
            TransactionHeader.SetRange(TransactionHeader."Receipt No.", PostedDelOrder."Order No.");
            if TransactionHeader.FindFirst() then begin
                PostedDelOrder."Store No." := TransactionHeader."Store No.";
                PostedDelOrder."POS Terminal No." := TransactionHeader."POS Terminal No.";
                PostedDelOrder."Transaction No." := TransactionHeader."Transaction No.";
            end;

            if (PostedDelOrder."General Status" = PostedDelOrder."General Status"::"In Progress") or
            (PostedDelOrder."General Status" = PostedDelOrder."General Status"::ERROR) then
                PostedDelOrder.Validate("General Status", PostedDelOrder."General Status"::Completed);

            IF PostedDelOrder."Created at Call Center" <> 'F20' then
                PostedDelOrder."Created at Call Center" := 'F20';

            if not PostedDelOrder.Insert(true) then
                PostedDelOrder.Modify(true);

            DelOrder.Delete(true);
        end;
    end;

    procedure SendFinalOrderToCC(TransHdr: Record "LSC Transaction Header"; ToStoreNo: Code[10]; var ProcText: Text[1024]): Boolean
    var
        ProcError: Boolean;
        PosDeliveryOrderSend: Record "LSC Posted Delivery Order";
        ErrorMsg: Text[1024];
    begin
        ErrorMsg := STRSUBSTNO('The record in table Transaction Header already exists. Identification fields and values: Store No.=''%1'',POS Terminal No.=''%2'',Transaction No.=''%3''', TransHdr."Store No.", TransHdr."POS Terminal No.", TransHdr."Transaction No.");
        Clear(OfflineCCWSClient);
        OfflineCCWSClient.SendFinalOrdertoCC(TransHdr, ToStoreNo, ProcError, ProcText);
        if (not ProcError) or (ErrorMsg = ProcText) then begin
            if PosDeliveryOrderSend.Get(TransHdr."Receipt No.") then
                PosDeliveryOrderSend."Rest. Web Service Status" += 1;
            PosDeliveryOrderSend.Modify();
        end;
        exit(not ProcError);
    end;

    procedure JobSendFinalOrder()
    var
        offlinecallFunctions: Codeunit "LSC Offl. CC Functions";
        PostedDelOrder, PostedDelOrderM : Record "LSC Posted Delivery Order";
        TransactionHdr: Record "LSC Transaction Header";
        ProcText: Text[1024];
        FiltTransHeader: Record "LSC Transaction Header";
    begin
        PostedDelOrder.Reset;
        PostedDelOrder.SetCurrentKey("Rest. Web Service Status");
        PostedDelOrder.SetFilter(
          "Rest. Web Service Status", '=%1|%2', PostedDelOrder."Rest. Web Service Status"::"Finalized-Not Sent", PostedDelOrder."Rest. Web Service Status"::"Cancelled-Not Sent");
        PostedDelOrder.SetFilter("Order Date", '>=%1', CalcDate('-30D', Today));
        if PostedDelOrder.Find('-') then begin
            repeat
                if not TransactionHdr.Get(PostedDelOrder."Store No.", PostedDelOrder."POS Terminal No.", PostedDelOrder."Transaction No.") then begin
                    TransactionHdr.Reset();
                    TransactionHdr.SetCurrentKey("Receipt No.", Date);
                    TransactionHdr.SetRange("Receipt No.", PostedDelOrder."Order No.");
                    if TransactionHdr.FindFirst() then begin
                        PostedDelOrder."Store No." := TransactionHdr."Store No.";
                        PostedDelOrder."POS Terminal No." := TransactionHdr."POS Terminal No.";
                        PostedDelOrder."Transaction No." := TransactionHdr."Transaction No.";
                        PostedDelOrder.Modify();
                    end;
                end;
                if PostedDelOrderM.Get(PostedDelOrder."Order No.") then begin
                    if TransactionHdr."Entry Status" = TransactionHdr."Entry Status"::Voided then
                        PostedDelOrderM."Rest. Web Service Status" := PostedDelOrderM."Rest. Web Service Status"::"Cancelled-Not Sent"
                    else
                        PostedDelOrderM."Rest. Web Service Status" := PostedDelOrderM."Rest. Web Service Status"::"Finalized-Not Sent";

                    IF PostedDelOrder."Created at Call Center" <> 'F20' then
                        PostedDelOrder."Created at Call Center" := 'F20';

                    PostedDelOrder.Modify();
                end;

                FiltTransHeader.Reset();
                if FiltTransHeader.Get(PostedDelOrder."Store No.", PostedDelOrder."POS Terminal No.", PostedDelOrder."Transaction No.") then begin
                    SendFinalOrderToCC(FiltTransHeader, PostedDelOrder."Created at Call Center", ProcText);
                end;
            until (PostedDelOrder.Next = 0);
            offlinecallFunctions.ReSendFinalOrdersToCC();
            CheckLogs();
        end;
    end;

    /*[EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Post Utility", 'OnAfterPostTransactionFiscalProcess', '', true, true)]
    local procedure "LSC POS Post Utility_OnAfterPostTransactionFiscalProcess"
(
var TransactionHeader: Record "LSC Transaction Header";
var FiscalProcessActive: Boolean;
var FiscalProcessOk: Boolean;
var POSTransaction: Record "LSC POS Transaction"
)
    var
        Hospitality: Codeunit "FSN Validate Hospitality";
        DelOrder: Record "LSC Delivery Order";
        ProcText: Text[1024];
        SheduleJobHeaderTemp: Record "LSC Scheduler Job Header" temporary;
    begin
        DelOrder.reset;
        if DelOrder.Get(POSTransaction."Receipt No.") then begin
            CLEAR(SheduleJobHeaderTemp);
            SheduleJobHeaderTemp.INIT;
            SheduleJobHeaderTemp.Code := 'FSNDELPOST';
            SheduleJobHeaderTemp.Text := FORMAT(DelOrder."Order No.");
            COMMIT;
            Hospitality.RUN(SheduleJobHeaderTemp);
            //SendFinalOrderToCC(TransactionHeader, DelOrder."Created at Call Center", ProcText);
        end;
    end;*/

    /// <summary>
    /// Verifies if the logs are being generated and check last log error
    /// </summary>
    local procedure CheckLogs()
    var
        PostedDelOrder: Record "LSC Posted Delivery Order";
        OffCCLog: Record "LSC Offl. CC Web Serv. Log";
    begin
        PostedDelOrder.Reset();
        PostedDelOrder.SetFilter("Rest. Web Service Status", ' = 3 | 5 ');
        if postedDelOrder.Find('-') then
            repeat
                OffCCLog.Reset();
                OffCCLog.SetRange("Receipt No.", PostedDelOrder."Order No.");
                if OffCCLog.FindLast() then begin
                    if OffCCLog."Result Text".Contains('The Posted Delivery Order already exists') or OffCCLog."Result Text".Contains('The Transaction Header already exists') then begin
                        PostedDelOrder."Rest. Web Service Status" += 1;
                        PostedDelOrder.Modify();
                    end
                end;
            until postedDelOrder.Next() = 0;
    end;

    local procedure ecommerceHighPriority(var handled: boolean)
    var
        postrans: Record "LSC POS Transaction";
        transLine: Record "LSC POS Trans. Line";
        parameter: Record "FSN Parameter";
        eposCtrl: Codeunit "LSC POS Control Interface";
        appRange1: label '00000APP01000000000';
        appRange2: label '00000APP01999999999';
        webRange1: label '000PV#1000000000000';
        webRange2: label '000PV#1000999999999';
        msg: Text;
        text0001: Label 'Primero Facture el pedido de %1 con el numero de Telefono %2.';
    begin
        if (parameter.Get('TPVBLOCK', 'ORDER_PRIORITY')) then begin
            if not (parameter.Activo) then
                exit;
        end else
            exit;

        postrans.setRange("Trans. Date", Today());
        postrans.setFilter("Receipt No.", '%1..%2|%3..%4', appRange1, appRange2, webRange1, webRange2);

        if not postrans.FindSet() then
            exit;

        handled := true;

        repeat
            transLine.SetCurrentKey("Receipt No.", "Entry Type", "Entry Status");
            transLine.setRange("Receipt No.", postrans."Receipt No.");
            transLine.setRange("Entry Type", transLine."Entry Type"::Payment);
            transLine.setRange("Entry Status", transLine."Entry Status"::" ");
            transLine.SetFilter(Number, '5|20');
            if transLine.FindSet() then begin
                msg := STRSUBSTNO(text0001, postrans.Comment, postrans."Sell-to Contact No.");
                if (postrans."Receipt No." = eposCtrl.GetDataGridKeyValue(eposCtrl.ActiveDataGrid())) then
                    handled := False;
            end;
        until (postrans.Next() = 0) or not Handled;

        if handled then
            Message(msg);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Controller", 'OnButtonPressed', '', false, false)]
    local procedure OnButtonPressed(var POSMenuLine: Record "LSC POS Menu Line"; var handled: Boolean);
    begin
        if POSMenuLine.Command = 'HOSP-ORDEREDIT' then begin
            ecommerceHighPriority(handled);
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
    var
        Hospitality: Codeunit "FSN Validate Hospitality";
        DelOrder: Record "LSC Delivery Order";
        ProcText: Text[1024];
        SheduleJobHeaderTemp: Record "LSC Scheduler Job Header" temporary;
        TransactionHeader: Record "LSC Transaction Header";
        POSDeliveryOrder: Record "LSC Posted Delivery Order";
        POSUtility: Codeunit "LSC POS Post Utility";
        FSNDTE: Codeunit "FSN Electronic Invoice";
    begin
        if Command in ['POST', 'VOID'] then begin
            if DelOrder.Get(POSTransLine."Receipt No.") then begin
                CLEAR(SheduleJobHeaderTemp);
                SheduleJobHeaderTemp.INIT;
                SheduleJobHeaderTemp.Code := 'FSNDELPOST';
                SheduleJobHeaderTemp.Text := FORMAT(DelOrder."Order No.");
                COMMIT;
                Hospitality.RUN(SheduleJobHeaderTemp);
                /* TransactionHeader.Reset();
                TransactionHeader.SetCurrentKey("Receipt No.");
                TransactionHeader.SetRange(TransactionHeader."Receipt No.", DelOrder."Order No.");
                IF TransactionHeader.FindLast() THEN
                     SendFinalOrderToCC(TransactionHeader, DelOrder."Created at Call Center", ProcText);*/
            end;
        end;
    end;


    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Post Utility", 'OnBeforeProcessTransaction', '', true, true)]
    local procedure "LSC POS Post Utility_OnBeforeProcessTransaction"
    (
        var PosTrans: Record "LSC POS Transaction";
        var TransSalesTaxEntryTEMP: Record "LSC Trans. SalesTax Entry"
    )
    var
        POSVoided: Record "LSC POS Voided Transaction";
        VoidedLine: Record "LSC POS Voided Trans. Line";
        VoidedInfoCodeEntry: Record "LSC POS Voided Infoc Entry";
        deliveryOrder: Record "LSC Delivery Order";
        PosTransDisc: Record "LSC POS Trans. Per. Disc. Type";
        TransDiscount: Codeunit "LSC POS Trans. Discounts";
        PosFunc: Codeunit "LSC POS Functions";
    begin
        if PosTrans."Entry Status" = PosTrans."Entry Status"::Voided then begin
            POSVoided.Reset();
            if POSVoided.Get(PosTrans."Receipt No.") then
                POSVoided.Delete(true);

            VoidedLine.reset;
            VoidedLine.SetRange(VoidedLine."Receipt No.", PosTrans."Receipt No.");
            VoidedLine.DeleteAll(true);

            VoidedInfoCodeEntry.reset;
            VoidedInfoCodeEntry.SetRange(VoidedInfoCodeEntry."Receipt No.", PosTrans."Receipt No.");
            VoidedInfoCodeEntry.DeleteAll(true);
        end;

        if deliveryOrder.get(PosTrans."Receipt No.") then begin
            PosFunc.PosTransDiscLoad(PosTrans."Receipt No.");
            PosFunc.InitTrackingInstanceID(PosTrans);
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
    begin
        if MenuLine."Command" = 'TIPOLOGIA0' then begin
            CommandRun := true;
            IsHandled := true;
            ApplyTipology0();
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

    begin
        clear(RecRef_g);
        if pSourceExprID = 'HO-COUNTD' then begin
            returnTxt := GetHosspOrderCountDown(pRecRef);
            Handled := true;
            exit
        end;
    end;

    var
        RecRef_g: RecordRef;
        KDSFunctions: Codeunit "LSC KDS Functions";
        POSSESSION: Codeunit "LSC POS Session";
        Txt1: Label 'VOIDED';
        Txt2: Label 'Started';
        Txt3: Label 'Finished';
        Txt4: Label '> 2 hrs over';
        Txt5: Label '%1 min over';
        Txt6: Label '%1 min';
        Txt7: Label 'Due Now';

    procedure GetHosspOrderCountDown(pRecRefTemp: RecordRef): text
    var

        PosTrans: Record "LSC POS Transaction";
        DeliveryOrder: Record "LSC Delivery Order";
        fieldRef: FieldRef;
        ReceiptNo: Code[20];
        TimeLength: Decimal;
        ReturnText: Text;
        DelTrip: Record "FSN Delivery Trip";
        lTxt1: Label 'Assigned';

    begin
        //RecRef_g := pRecRefTemp;

        FieldRef := pRecRefTemp.Field(PosTrans.FieldNo("Receipt No."));
        ReceiptNo := FieldRef.Value;

        TimeLength := 0;
        ReturnText := '';
        IF DeliveryOrder.GET(ReceiptNo) THEN BEGIN
            IF DelTrip.GET(ReceiptNo) AND //WVILLALTA 12.20-
              (DelTrip."General Status" = DelTrip."General Status"::InProcess) AND
              (DelTrip."Trip. Status" IN [DelTrip."Trip. Status"::"Assigned Driver", DelTrip."Trip. Status"::"Trip Starting"]) AND
              (DelTrip."Trip No. (LS Retail)" > 0) THEN
                ReturnText := lTxt1
            ELSE                            //WVILLALTA 12.20+
                IF (DeliveryOrder."Contact Pickup Time" <> 0T) AND
                   (DeliveryOrder."Time Created" <> 0T) AND
                   (DeliveryOrder."General Status" = 0)
                THEN BEGIN
                    TimeLength := (TODAY - DeliveryOrder."Order Date") * 60 * 24 + (TIME - DeliveryOrder."Contact Pickup Time") / 60000;
                    TimeLength := ROUND(TimeLength, 1.0);
                    ReturnText := STRSUBSTNO(Txt5, FORMAT(TimeLength));
                    //IF TimeLength > 120 THEN
                    //ReturnText := Txt4
                    //ELSE                       //CSMQ290317 Se reviso la cantidad de tiempo y se dejo indefinida
                    IF TimeLength < 0 THEN
                        ReturnText := STRSUBSTNO(Txt6, FORMAT(ABS(TimeLength)))
                    ELSE
                        IF TimeLength = 0 THEN
                            ReturnText := Txt7;
                END;
        END;

        EXIT(ReturnText);
    end;

    /////////////////////////////////////////////////PREFACTURA POS CC/////////////////////////////////////////////////////////////
    procedure InitRequest(var pReqXml: XmlDocument; pRequestID: Code[30]; var pRequestNodeList: array[3] of Text[50]; var pResponseNodeList: array[5] of Text[50]; var pParentNodeIndex: Integer; var pParentNodeList: array[5] of Text[50]; var pNode: XmlNode; var pProcessError: Boolean; var pErrorText: Text[1024]): Boolean
    begin
        //InitRequest

        IF NOT RequestSetupOk(pRequestID, pErrorText) THEN BEGIN
            pProcessError := TRUE;
            EXIT(FALSE);
        END;

        WSFunc.GetHeaderReqNodes(pRequestID, pRequestNodeList);
        WSFunc.GetHeaderResNodes(pRequestID, pResponseNodeList);

        WSFunc.CreateRequest(pReqXml, pRequestID, pRequestNodeList, pParentNodeIndex, pParentNodeList, pNode);

        EXIT(TRUE);
    end;

    local procedure GetWebServerList(pRequestID: Text[30]; var pWebServerList: Record "LSC WS Server Buffer" temporary)
    var
        FuncProfileWebServer: Record "LSC POS Func. Profile Web Serv";
        WebServerExt: Record "LSC Web Req. Type Server Ext." temporary;// "Web Request Type Server Ext." temporary;
        WSRequest: Record "LSC WS Request";
        ServerExt: Record "LSC Web Req. Type Server Ext.";//"Web Request Type Server Ext.";
        UseBase: Boolean;
        LineNo: Integer;
    begin
        //GetWebURIList
        LineNo := 0;
        IF PosFuncProfile."Profile ID" <> '' THEN BEGIN
            //LS7.1-15 -
            IF PosFuncProfile."Profile ID" = '##TESTCONN' THEN BEGIN //Internal key word.
                LineNo := LineNo + 1;
                pWebServerList.INIT;
                pWebServerList."Entry No." := LineNo;
                pWebServerList."Local Request" := FALSE;
                pWebServerList."Dist. Location" := PosFuncProfile."Online Trans. Backup";
                pWebServerList.INSERT;
            END ELSE BEGIN
                //LS7.1-15 -
                FuncProfileWebServer.RESET;
                FuncProfileWebServer.SETCURRENTKEY("Profile ID", "Request ID", Priority);
                FuncProfileWebServer.ASCENDING(FALSE);
                FuncProfileWebServer.SETRANGE("Profile ID", PosFuncProfile."Profile ID");
                FuncProfileWebServer.SETRANGE("Request ID", pRequestID);
                IF NOT FuncProfileWebServer.FIND('-') THEN
                    FuncProfileWebServer.SETRANGE("Request ID", '');
                IF FuncProfileWebServer.FIND('-') THEN
                    REPEAT
                        LineNo := LineNo + 1;
                        pWebServerList.INIT;
                        pWebServerList."Entry No." := LineNo;
                        pWebServerList."Local Request" := FuncProfileWebServer."Local Request";
                        pWebServerList."Dist. Location" := FuncProfileWebServer."Dist. Location";
                        pWebServerList.INSERT;
                    UNTIL FuncProfileWebServer.NEXT = 0;
            END; //LS7.1-15
        END ELSE BEGIN
            LineNo := LineNo + 1;
            pWebServerList.INIT;
            pWebServerList."Entry No." := LineNo;
            pWebServerList."Local Request" := webServiceSetup."Only Local Request";
            pWebServerList."Dist. Location" := '';
            pWebServerList.INSERT;
        END;
    end;

    procedure RequestSetupOk(pRequestID: Text[30]; var pErrorText: Text[1024]): Boolean
    var
        lText001: Label 'Web service module is not active';
        lText002: Label 'Web request %1 not found';
        lText003: Label 'Web request %1 is not active';
    begin
        //RequestSetupOk

        IF NOT WebServiceSetup."Web Service is Active" THEN BEGIN
            pErrorText := lText001;
            EXIT(FALSE);
        END;

        IF NOT WSRequest.GET(pRequestID) THEN BEGIN
            pErrorText := STRSUBSTNO(lText002, pRequestID);
            EXIT(FALSE);
        END;

        IF NOT WSRequest."Web Request is Active" THEN BEGIN
            pErrorText := STRSUBSTNO(lText003, pRequestID);
            EXIT(FALSE);
        END;

        IF NOT WSFunc.XMLHeaderSetupOk(pRequestID, pErrorText) THEN
            EXIT(FALSE);

        EXIT(TRUE);
    end;
    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    local procedure SendRequest(pRequestID: Text[30]; var pxmlRequest: Text; var pxmlResponse: Text)
    var
        WebServerList: Record "LSC WS Server Buffer" temporary;
    begin
        //SendRequest
        GetWebServerList(pRequestID, WebServerList);

        WebServicesConn.SendRequest(pRequestID, WebServerList, pxmlRequest, pxmlResponse);
    end;

    procedure SendPosTransCCBC(pRequestID: Text[30]; var pPOSTransaction: Record "LSC POS Transaction"; var pProcessError: Boolean; var pErrorText: Text[1024]): Boolean
    var
        ReqXml: XmlDocument;
        ResXml: XmlDocument;
        BodyNode: XmlNode;
        Node: XmlNode;
        LineNode: XmlNode;
        NodeList: XmlNodeList;
        xmlRequest: Text;
        xmlResponse: Text;
        RequestID: Text[30];
        RequestNodeList: array[3] of Text[50];
        ResponseNodeList: array[5] of Text[50];
        ParentNodeIndex: Integer;
        ParentNodeList: array[5] of Text[50];
        NodeName: Text[50];
        Response_Code: Code[30];
        ReqNodeList: Record "LSC WS Node Buffer" temporary;
        NodeBuffer: Record "LSC WS Node Buffer" temporary;
        Index: Integer;
        RecRef: RecordRef;
        POSTransaction: Record "LSC POS Transaction";
        POSTransLine: Record "LSC POS Trans. Line";
        POSTransPeriodicDisc: Record "LSC POS Trans. Per. Disc. Type";
        POSTransInfocodeEntry: Record "LSC POS Trans. Infocode Entry";
        POSDataEntry: Record "LSC POS Data Entry";
        VoucherEntries: Record "LSC Voucher Entries";
        OfferPosCalculation: Record "LSC Offer Pos Calculation";
        RecRefTemp: RecordRef;
        POSTransactionTemp: Record "LSC POS Transaction" temporary;
        POSTransLineTemp: Record "LSC POS Trans. Line" temporary;
        POSTransPeriodicDiscTemp: Record "LSC POS Trans. Per. Disc. Type" temporary;
        POSTransInfocodeEntryTemp: Record "LSC POS Trans. Infocode Entry" temporary;
        POSDataEntryTemp: Record "LSC POS Data Entry" temporary;
        VoucherEntriesTemp: Record "LSC Voucher Entries" temporary;
        OfferPosCalculationTemp: Record "LSC Offer Pos Calculation" temporary;
        //PosTrLineDisplStatRoutTemp: Record "Pos Tr. Line Displ. Stat. Rout" temporary;
        FlowFieldBuffer: Record "LSC FlowField Buffer" temporary;
        POSCardRequestEntry: Record "FSN POS Card Request Entry";
        POSCardRequestEntryTmp: Record "FSN POS Card Request Entry" temporary;
        CSTable: Record "FSN WebServiceTable";
        CSTableTmp: Record "FSN WebServiceTable" temporary;
        POSCardEntries: Record "LSC POS Card Entry";
        POSCardEntriesTMP: Record "LSC POS Card Entry" temporary;
        OdataCNN: Codeunit "FSN OData Conexion";
        POSMenuLine: Record "LSC POS Menu Line";
        StringXML: Text;
        FilterString: Text;
        FileSystem: DotNet StreamWriter;
        Directory: DotNet DirNet;
        RequestSetup: Record "LSC WS Request Setup";
        DeliveryContactAddress: Record "LSC Delivery Contact Address";
        DeliveryContactAddressTemp: Record "LSC Delivery Contact Address" temporary;
        Contact: Record Contact;
        ContactTemp: Record Contact temporary;
        addressTypeInt: Integer;
        ErrorEntryType: Label 'ERROR Entry type';
    begin
        //SendPosTrans
        //GetWebServiceSetup;
        WebServiceSetup.GET;
        RequestID := pRequestID;
        Response_Code := '0000';

        IF NOT InitRequest(ReqXml, RequestID, RequestNodeList, ResponseNodeList, ParentNodeIndex, ParentNodeList, BodyNode, pProcessError, pErrorText) THEN
            EXIT(FALSE);

        IF NOT WSFunc.AddChildNodeListText(RequestID, 0, ParentNodeIndex, ParentNodeList, 'Update_Action', 'Update-Add',
           ReqNodeList, Response_Code, pErrorText)
        THEN BEGIN
            pProcessError := TRUE;
            EXIT(FALSE);
        END;
        WSFunc.AppendChildNodeList(BodyNode, ReqNodeList);

        //POS Transaction
        POSTransaction.SETRANGE("Receipt No.", pPOSTransaction."Receipt No.");
        RecRef.GETTABLE(POSTransaction);
        RecRefTemp.GETTABLE(POSTransactionTemp);
        WSFunc.CopyTableToTempTable(RecRef, RecRefTemp, FlowFieldBuffer);
        IF NOT WSFunc.SetTableChildNodes(RequestID, 0, BodyNode, ParentNodeIndex, ParentNodeList, 'LSC POS Transaction',
          RecRefTemp, FlowFieldBuffer, Response_Code, pErrorText)
        THEN BEGIN
            pProcessError := TRUE;
            EXIT(FALSE);
        END;

        //POS Trans. Line
        POSTransLine.SETRANGE("Receipt No.", pPOSTransaction."Receipt No.");
        RecRef.GETTABLE(POSTransLine);
        RecRefTemp.GETTABLE(POSTransLineTemp);
        WSFunc.CopyTableToTempTable(RecRef, RecRefTemp, FlowFieldBuffer);
        IF NOT WSFunc.SetTableChildNodes(RequestID, 0, BodyNode, ParentNodeIndex, ParentNodeList, 'LSC POS Trans. Line',
          RecRefTemp, FlowFieldBuffer, Response_Code, pErrorText)
        THEN BEGIN
            pProcessError := TRUE;
            EXIT(FALSE);
        END;

        //POS Trans. Periodic Disc.
        POSTransPeriodicDisc.SETRANGE("Receipt No.", pPOSTransaction."Receipt No.");
        RecRef.GETTABLE(POSTransPeriodicDisc);
        RecRefTemp.GETTABLE(POSTransPeriodicDiscTemp);
        WSFunc.CopyTableToTempTable(RecRef, RecRefTemp, FlowFieldBuffer);
        IF NOT WSFunc.SetTableChildNodes(RequestID, 0, BodyNode, ParentNodeIndex, ParentNodeList, 'LSC POS Trans. Per. Disc. Type',
          RecRefTemp, FlowFieldBuffer, Response_Code, pErrorText)
        THEN BEGIN
            pProcessError := TRUE;
            EXIT(FALSE);
        END;

        //POS Trans. Infocode Entry
        POSTransInfocodeEntry.SETRANGE("Receipt No.", pPOSTransaction."Receipt No.");
        RecRef.GETTABLE(POSTransInfocodeEntry);
        RecRefTemp.GETTABLE(POSTransInfocodeEntryTemp);
        WSFunc.CopyTableToTempTable(RecRef, RecRefTemp, FlowFieldBuffer);
        IF NOT WSFunc.SetTableChildNodes(RequestID, 0, BodyNode, ParentNodeIndex, ParentNodeList, 'LSC POS Trans. Infocode Entry',
          RecRefTemp, FlowFieldBuffer, Response_Code, pErrorText)
        THEN BEGIN
            pProcessError := TRUE;
            EXIT(FALSE);
        END;

        //POS Data Entry
        POSDataEntry.RESET;
        POSDataEntry.SETCURRENTKEY("Created by Receipt No.");
        POSDataEntry.SETRANGE("Created by Receipt No.", pPOSTransaction."Receipt No.");
        RecRef.GETTABLE(POSDataEntry);
        RecRefTemp.GETTABLE(POSDataEntryTemp);
        WSFunc.CopyTableToTempTable(RecRef, RecRefTemp, FlowFieldBuffer);

        POSDataEntry.RESET;
        POSDataEntry.SETCURRENTKEY("Applied by Receipt No.");
        POSDataEntry.SETRANGE("Applied by Receipt No.", pPOSTransaction."Receipt No.");
        RecRef.GETTABLE(POSDataEntry);
        RecRefTemp.GETTABLE(POSDataEntryTemp);
        WSFunc.CopyTableToTempTable(RecRef, RecRefTemp, FlowFieldBuffer);

        IF NOT WSFunc.SetTableChildNodes(RequestID, 0, BodyNode, ParentNodeIndex, ParentNodeList, 'LSC POS Data Entry',
          RecRefTemp, FlowFieldBuffer, Response_Code, pErrorText)
        THEN BEGIN
            pProcessError := TRUE;
            EXIT(FALSE);
        END;

        //Voucher Entries
        VoucherEntries.SETCURRENTKEY("Receipt Number", "Store No.", "POS Terminal No.");
        VoucherEntries.SETRANGE("Receipt Number", pPOSTransaction."Receipt No.");
        RecRef.GETTABLE(VoucherEntries);
        RecRefTemp.GETTABLE(VoucherEntriesTemp);
        WSFunc.CopyTableToTempTable(RecRef, RecRefTemp, FlowFieldBuffer);
        IF NOT WSFunc.SetTableChildNodes(RequestID, 0, BodyNode, ParentNodeIndex, ParentNodeList, 'LSC Voucher Entries',
          RecRefTemp, FlowFieldBuffer, Response_Code, pErrorText)
        THEN BEGIN
            pProcessError := TRUE;
            EXIT(FALSE);
        END;

        //Offer Pos Calculation
        OfferPosCalculation.SETRANGE("Receipt No.", pPOSTransaction."Receipt No.");
        RecRef.GETTABLE(OfferPosCalculation);
        RecRefTemp.GETTABLE(OfferPosCalculationTemp);
        WSFunc.CopyTableToTempTable(RecRef, RecRefTemp, FlowFieldBuffer);
        IF NOT WSFunc.SetTableChildNodes(RequestID, 0, BodyNode, ParentNodeIndex, ParentNodeList, 'LSC Offer Pos Calculation',
          RecRefTemp, FlowFieldBuffer, Response_Code, pErrorText)
        THEN BEGIN
            pProcessError := TRUE;
            EXIT(FALSE);
        END;

        //FSN POS Card Request Entry
        POSCardRequestEntry.SETRANGE("Receipt No.", pPOSTransaction."Receipt No.");
        RecRef.GETTABLE(POSCardRequestEntry);
        RecRefTemp.GETTABLE(POSCardRequestEntryTmp);
        WSFunc.CopyTableToTempTable(RecRef, RecRefTemp, FlowFieldBuffer);
        IF NOT WSFunc.SetTableChildNodes(RequestID, 0, BodyNode, ParentNodeIndex, ParentNodeList, 'FSN POS Card Request Entry',//28981
          RecRefTemp, FlowFieldBuffer, Response_Code, pErrorText)
        THEN BEGIN
            pProcessError := TRUE;
            EXIT(FALSE);
        END;

        //CS Web Service Table
        CSTable.Reset();
        CSTable.SETRANGE(CSTable.LastSlipNo, pPOSTransaction."Receipt No.");
        RecRef.GETTABLE(CSTable);
        RecRefTemp.GETTABLE(CSTableTmp);
        WSFunc.CopyTableToTempTable(RecRef, RecRefTemp, FlowFieldBuffer);
        IF NOT WSFunc.SetTableChildNodes(RequestID, 0, BodyNode, ParentNodeIndex, ParentNodeList, 'FSN WebServiceTable',
          RecRefTemp, FlowFieldBuffer, Response_Code, pErrorText)
        THEN BEGIN
            pProcessError := TRUE;
            EXIT(FALSE);
        END;

        POSCardEntries.SETRANGE(POSCardEntries."Receipt No.", pPOSTransaction."Receipt No.");
        RecRef.GETTABLE(POSCardEntries);
        RecRefTemp.GETTABLE(POSCardEntriesTMP);
        WSFunc.CopyTableToTempTable(RecRef, RecRefTemp, FlowFieldBuffer);
        IF NOT WSFunc.SetTableChildNodes(RequestID, 0, BodyNode, ParentNodeIndex, ParentNodeList, 'LSC POS Card Entry',
          RecRefTemp, FlowFieldBuffer, Response_Code, pErrorText)
        THEN BEGIN
            pProcessError := TRUE;
            EXIT(FALSE);
        END;

        CSTable.Reset();
        IF CSTable.Get(pPOSTransaction."Receipt No.") THEN
            if not Evaluate(addressTypeInt, CSTable."Value Text 1") then begin
                Message(ErrorEntryType);
                exit(FALSE);
            end;

        //LSC Delivery Contact Address
        DeliveryContactAddress.SetCurrentKey("Phone No.", "Address Type");
        DeliveryContactAddress.SETRANGE(DeliveryContactAddress."Phone No.", CSTable."Sell-to Contact No.");
        DeliveryContactAddress.SETRANGE(DeliveryContactAddress."Address Type", addressTypeInt);
        IF DeliveryContactAddress.FindFirst() THEN;
        RecRef.GETTABLE(DeliveryContactAddress);
        RecRefTemp.GETTABLE(DeliveryContactAddressTemp);
        WSFunc.CopyTableToTempTable(RecRef, RecRefTemp, FlowFieldBuffer);
        IF NOT WSFunc.SetTableChildNodes(RequestID, 0, BodyNode, ParentNodeIndex, ParentNodeList, 'LSC Delivery Contact Address',
          RecRefTemp, FlowFieldBuffer, Response_Code, pErrorText)
        THEN BEGIN
            pProcessError := TRUE;
            EXIT(FALSE);
        END;


        //Contact
        Contact.SetCurrentKey("No.");
        Contact.SETRANGE(Contact."No.", CSTable."Sell-to Contact No.");
        IF Contact.FindFirst() THEN;
        RecRef.GETTABLE(Contact);
        RecRefTemp.GETTABLE(ContactTemp);
        WSFunc.CopyTableToTempTable(RecRef, RecRefTemp, FlowFieldBuffer);
        IF NOT WSFunc.SetTableChildNodes(RequestID, 0, BodyNode, ParentNodeIndex, ParentNodeList, 'Contact',
          RecRefTemp, FlowFieldBuffer, Response_Code, pErrorText)
        THEN BEGIN
            pProcessError := TRUE;
            EXIT(FALSE);
        END;

        //xmlRequest := ReqXml.OuterXml;
        xmlRequest := XMLDomMgt.ReturnInnerTextfromXMLDocument(ReqXml);
        StringXML := xmlRequest;
        SendRequest(RequestID, xmlRequest, xmlResponse);
        IF NOT WSFunc.LoadResponse(xmlResponse, ResXml, RequestID, ResponseNodeList, ParentNodeIndex, ParentNodeList, BodyNode, pProcessError, pErrorText) THEN
            EXIT(FALSE);

        //comprobar si existe la carpeta, si no existe crearla
        if not Directory.Exists('C:\temp\WSFSN\') then
            Directory.CreateDirectory('C:\temp\WSFSN\');

        //guardar el xml en la carpeta
        if Directory.Exists('C:\temp\WSFSN\') then begin
            FilterString := 'C:\temp\WSFSN\' + pRequestID + '.xml';
            FileSystem := FileSystem.StreamWriter(FilterString);
            FileSystem.Write(StringXML);
            FileSystem.Close();
        end;

        pProcessError := FALSE;
        EXIT(TRUE);

    end;

    procedure SendToServerOrder(var pErrorTextSend: text; pPOSTransaction: Record "LSC POS Transaction"): Boolean
    var
        pPOSTransaction2: Record "LSC POS Transaction";
        pStore: Record "LSC Store";
        pError: Boolean;
        pErrorText: Text[1024];
        CSWebTable: Record "FSN WebServiceTable";
        DeliveryOrder: Record "LSC Delivery Order";
        Proerror: Boolean;
        ErrorText: Text;
    begin
        //CLEAR(CSWebTable);
        //if CSWebTable.GET(pPOSTransaction."Receipt No.") then;//Found

        if pStore.GET(pPOSTransaction."Store No.") then
            POSFuncProfile.GET(pStore."Functionality Profile");

        SetPosFuncProfile(POSFuncProfile);
        if SendPosTransCCBC('SEND_POSTRANS_BACKUP_BC', pPOSTransaction, pError, pErrorText) THEN BEGIN
            if pPOSTransaction2.GET(pPOSTransaction."Receipt No.") THEN
                if NOT DeliveryOrder.GET(pPOSTransaction."Receipt No.") THEN
                    pPOSTransaction2.DELETE(TRUE);
            exit(true);
        end else begin
            pErrorTextSend := pErrorText;
            exit(false);
        end;
    end;

    procedure SetPosFuncProfile(var pPosFuncProfile: Record "LSC POS Func. Profile")
    begin
        //SetPosFuncProfile
        PosFuncProfile := pPosFuncProfile;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Post Utility", 'OnAfterPostTransactionFiscalProcess', '', true, true)]
    local procedure "LSC POS Post Utility_OnAfterPostTransactionFiscalProcess"
    (
        var TransactionHeader: Record "LSC Transaction Header";
        var FiscalProcessActive: Boolean;
        var FiscalProcessOk: Boolean;
        var POSTransaction: Record "LSC POS Transaction"
    )
    var
        Hospitality: Codeunit "FSN Validate Hospitality";
        DelOrder: Record "LSC Delivery Order";
        ProcText: Text[1024];
        SheduleJobHeaderTemp: Record "LSC Scheduler Job Header" temporary;
    begin

        IF POSSESSION.GetValue('FSNCREATEPREFAC') = 'TRUE' THEN begin
            if POSTransaction."Entry Status" <> POSTransaction."Entry Status"::Voided then
                FiscalProcessOk := false;
            FiscalProcessActive := true;
        end;
    end;


    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Transaction Events", 'OnBeforeTransactionTendered', '', true, true)]
    local procedure "LSC POS Transaction Events_OnBeforeTransactionTendered"
    (
        var POSTransaction: Record "LSC POS Transaction";
        var TenderType: Record "LSC Tender Type";
        var VoidInProcess: Boolean;
        var Balance: Decimal
    )
    begin
        //Evita procesar la transaccion con medias de pago.
        IF POSSESSION.GetValue('FSNCREATEPREFAC') = 'TRUE' THEN
            VoidInProcess := true;
    end;


    procedure ValidatePX(): Boolean
    var
        PostR: Codeunit "LSC POS Transaction";
        POSTrans: Record "LSC POS Transaction";
        transLine: Record "LSC POS Trans. Line";
        IncExpAccount: Record "LSC Income/Expense Account";
        filter: Text;
    begin
        filter := '18|19|20|21';

        if POSTrans.Get(PostR.GetReceiptNo()) then begin
            transLine.SetRange("Store No.", POSTrans."Store No.");
            transLine.SetRange("Entry Type", transLine."Entry Type"::IncomeExpense);
            transLine.SetRange("POS Terminal No.", POSTrans."POS Terminal No.");
            transLine.SetRange("Receipt No.", POSTrans."Receipt No.");
            transLine.SetFilter(Number, filter);
            if transLine.FindFirst() then begin
                Message('No se puede procesar la prefactura/rutas DAF, con transacciones de PUNTOXPRESS');
                exit(true);
            end;
        end;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Controller", 'OnButtonPressed', '', true, true)]
    local procedure "EPOS Controler_OnButtonPressed"
    (
        var POSMenuLine: Record "LSC POS Menu Line";
        var handled: Boolean
    )
    var
        POSTransactionTMP: Record "LSC POS Transaction" temporary;
        POSTransaction_l: Record "LSC POS Transaction";
        TEXT000: Label 'Pedido enviado a CALL CENTER con No %1';
        TEXT001: Label 'Debe dar clic en "PROCESAR PREFACTURA BC';
        TEXT002: Label 'Debe de definir una media de pago para prefactura BC';
        TEXT003: Label 'Error WS: %1';
        TEXT004: Label 'Debe definir tipo domicilio(CASA, TABAJO, OTROS, PARA LLEVAR)';
        LoadingText: Label 'Procesando Pedido BC, Espere.......';
        Windows: Dialog;
        ErrorText: Text;
        WebTable: Record "FSN WebServiceTable";
        PG: Page "FSN Web Table Page";
        DelOrd: Record "LSC Delivery Order";
        POSGUI: Codeunit "LSC POS GUI";
        XMLRequest: Text;
        XMLResponse: Text;
        RequestID: Text[50];
        PosMenuLineTemp: Record "LSC POS Menu Line" Temporary;
        Processed: Boolean;
        MsgResult: Text;
        FSNUtility: Codeunit "FSN Utility";
        Mensaj000: Label 'Debe de agregar cliente a la transaccion';
        RC: Code[20];
    begin
        if POSMenuLine.Command = 'FSNCREATEPREFAC' then//Levanta panel POS para procesar prefactura BC
            if not ValidatePX() then
                ChowModalPOSCC;

        if POSSESSION.GetValue('FSNCREATEPREFAC') = 'TRUE' then begin //Valida que no se use POST(REGISTRAR CALL CENTER)
            IF POSMenuLine.Command = 'POST' THEN BEGIN
                handled := true;
                Message(TEXT001);
            END;
        end;

        //Valida Balance
        //envia WS CC 
        IF POSMenuLine.Command = 'FSNPOSTCC' THEN BEGIN
            if not ValidatePX() then begin
                Windows.OPEN(LoadingText);
                Windows.UPDATE;
                if POSSESSION.GetValue('Balance') in ['0', '0.00'] then begin
                    IF POSTransaction_l.Get(PosTransGlobalC.GetReceiptNo()) THEN BEGIN
                        if POSSESSION.GetValue('FSNCREATEPREFAC') = 'TRUE' then begin
                            POSTransaction_l."Entry Status" := POSTransaction_l."Entry Status"::Suspended;
                            POSTransactionTMP.Copy(POSTransaction_l);
                            //VALIDA SI EXISTE WSTABLE
                            if WebTable.Get(POSTransaction_l."Receipt No.") then begin
                                IF not (WebTable."Value Text 1" = '') THEN BEGIN
                                    if SendToServerOrder(ErrorText, POSTransactionTMP) then begin
                                        RC := IncStr(POSTransaction_l."Receipt No.");
                                        InsertTmpTrans(RC, POSSESSION.WorkShiftNo, '', 0, false, '');
                                        POSSESSION.SetValue('FSNCREATEPREFAC', 'FALSE');
                                        POSSESSION.SetValue('CURRORDER', '');
                                        EPosCtrl.PostEvent('RUNCOMMAND', 'LOGOFF', '', '');
                                        Windows.Close();
                                        Message(STRSUBSTNO(TEXT000, WebTable."Sell-to Contact No."));
                                    end else begin
                                        Windows.Close();
                                        Message(STRSUBSTNO(TEXT003, ErrorText));
                                    end;
                                end else begin
                                    Windows.Close();
                                    Message(TEXT004);
                                end;
                            end;
                        end;
                    END;
                end else begin
                    Windows.Close();
                    Message(TEXT002);
                end;
            end;
        END;

        IF POSMenuLine.Command = 'FSNSENDAF' then begin
            if not ValidatePX() then
                IF POSTransaction_l.Get(PosTransGlobalC.GetReceiptNo()) THEN begin
                    CreateWebSe(POSTransaction_l."Receipt No.");
                    IF WebTable.Get(POSTransaction_l."Receipt No.") THEN begin
                        DelOrd.Reset();
                        if not DelOrd.Get(POSTransaction_l."Receipt No.") then begin
                            If POSTransaction_l."Customer No." <> '' then begin
                                POSSESSION.SetValue('CURRORDER', POSTransaction_l."Receipt No.");
                                POSSESSION.SetValue('PDAF', 'TRUE');
                                CreateDeliveryOrder(POSTransaction_l);
                                WebServiceTableProceess(POSTransaction_l);
                                IF WebTable.Get(POSTransaction_l."Receipt No.") THEN
                                    PG.SETGLOBALVALUE(WebTable);
                                Commit();
                                PG.RunModal();
                                NewLine(POSTransaction_l."Receipt No.");
                            end;
                        end;
                    end;
                end
        end;

        if POSMenuLine.Command = 'LOGOFF' then begin
            if WebTable.get(PosTransGlobalC.GetReceiptNo()) then begin
                IF WebTable."WS Request" = 'SEND_POSTRANS_BACKUP_BC' THEN BEGIN
                    POSSESSION.SetValue('FSNCREATEPREFAC', 'FALSE');
                    POSSESSION.SetValue('CURRORDER', '');
                END
            end;
        end;
    end;



    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Transaction Events", 'OnAfterVoidPressed', '', true, true)]
    local procedure "LSC POS Transaction Events_OnAfterVoidPressed"(var POSTransaction: Record "LSC POS Transaction")
    var
        WebTable: Record "FSN WebServiceTable";
    begin

        IF POSSESSION.GetValue('FSNCREATEPREFAC') = 'TRUE' THEN begin
            POSSESSION.SetValue('FSNCREATEPREFAC', 'FALSE');
        end;
    end;

    procedure ChowModalPOSCC()
    var
        NewReceiptNo: Code[20];
        PosFunc: Codeunit "LSC POS Functions";
        WSTable: Record "FSN WebServiceTable";
        POSTransaction: Record "LSC POS Transaction";
    begin

        POSSESSION.SetValue('FSNCREATEPREFAC', 'TRUE');
        CreatePosTransaction(PosTransGlobalC.GetReceiptNo());

        //ChowPosTransaction(NewReceiptNo);//borrar
    end;

    procedure ValExPosTransaction(NewReceiptNoVal: Code[20]): Boolean
    var
        PosTransactionFilter: Record "LSC POS Transaction";
    begin
        PosTransactionFilter.SetCurrentKey("Receipt No.");
        PosTransactionFilter.SetRange("Receipt No.", NewReceiptNoVal);
        IF PosTransactionFilter.FindFirst() THEN BEGIN
            exit(true);
        END else
            exit(false);
    end;

    procedure ChowPosTransaction(ChowReceipt: Code[20])
    var
        HosPosStartup: Codeunit "LSC Hospitality POS Startup";
    begin
        POSSESSION.SetValue('FSNCREATEPREFAC', 'TRUE');
        POSSESSION.SetValue('CURRORDER', ChowReceipt);
        HosPosStartup.DirectEdit(true);
    end;

    procedure CreateWebSe(recibo: Code[20])
    var
        myInt: Integer;
        GlobalsCSWebServiceTable: Record "FSN WebServiceTable";
    begin
        if not GlobalsCSWebServiceTable.Get(recibo) then begin
            GlobalsCSWebServiceTable.INIT();
            GlobalsCSWebServiceTable.LastSlipNo := recibo;
            GlobalsCSWebServiceTable.insert();
        end;
    end;

    procedure CreatePosTransaction(NewReceiptNoVal: Code[20])
    var
        NewPOSTransLine: Record "LSC POS Trans. Line";
        HosPosStartup: Codeunit "LSC Hospitality POS Startup";
        GlobalsCSWebServiceTable: Record "FSN WebServiceTable";
        FREETEXT: Label 'PREFACTURA BC, SALA ORIGEN %1';
        ERRORTEXT: Label 'linea PREFACTURA BC, SALA ORIGEN ya existe.';
    begin
        //InsertTmpTrans(NewReceiptNoVal, POSSESSION.WorkShiftNo, '', 0, false, '');//borrar

        if not (GlobalsCSWebServiceTable.Get(NewReceiptNoVal)) then begin
            NewPOSTransLine.Init();
            NewPOSTransLine."Receipt No." := NewReceiptNoVal;
            NewPOSTransLine."Store No." := POSSESSION.StoreNo();
            NewPOSTransLine."POS Terminal No." := POSSESSION.TerminalNo();
            NewPOSTransLine."Entry Type" := NewPOSTransLine."Entry Type"::FreeText;
            NewPOSTransLine."Text Type" := NewPOSTransLine."Text Type"::"Freetext Input";
            NewPOSTransLine.VALIDATE(NewPOSTransLine.Description, STRSUBSTNO(FREETEXT, POSSESSION.StoreNo()));
            NewPOSTransLine."Line No." := 41;
            IF NewPOSTransLine.Insert(true) then;

            GlobalsCSWebServiceTable.INIT();
            GlobalsCSWebServiceTable.LastSlipNo := NewReceiptNoVal;
            GlobalsCSWebServiceTable."WS Request" := 'SEND_POSTRANS_BACKUP_BC';
            GlobalsCSWebServiceTable.insert();


            POSSESSION.SetValue('FSNCREATEPREFAC', 'TRUE');
            POSSESSION.SetValue('CURRORDER', NewReceiptNoVal);
            //HosPosStartup.DirectEdit(true);
        end else
            Message(ERRORTEXT);
    end;

    procedure NewLine(NewReceiptNoVal: Code[20])
    var
        myInt: Integer;
        NewPOSTransLine: Record "LSC POS Trans. Line";
        FREETEXT: Label 'RUTA DE DAF DESDE SALA %1';
    begin
        NewPOSTransLine.Init();
        NewPOSTransLine."Receipt No." := NewReceiptNoVal;
        NewPOSTransLine."Store No." := POSSESSION.StoreNo();
        NewPOSTransLine."POS Terminal No." := POSSESSION.TerminalNo();
        NewPOSTransLine."Entry Type" := NewPOSTransLine."Entry Type"::FreeText;
        NewPOSTransLine."Text Type" := NewPOSTransLine."Text Type"::"Freetext Input";
        NewPOSTransLine.VALIDATE(NewPOSTransLine.Description, STRSUBSTNO(FREETEXT, POSSESSION.StoreNo()));
        NewPOSTransLine."Line No." := 41;
        IF NewPOSTransLine.Insert(true) then;

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
        PG: Page "FSN Web Table Page";
        ValCustomer: Record Customer;
        ComtactV: Record Contact;
        TEXT005: Label 'Debe definir Cliente';
        TEXT006: Label 'Cliente debe de tener Numero de Telefono';
    begin
        if PosEvent.ActivePanel = '#POS' THEN
            if PosEvent.EventType in [
                Enum::"LSC POS Event Type"::DATAROWDOUBLECLICK
            ] then begin
                POSLines.GetCurrentLine(POSLine_l);
                if (POSLine_l."Entry Type" = POSLine_l."Entry Type"::FreeText) AND
                    (POSLine_l."Entry Status" = POSLine_l."Entry Status"::" ") THEN begin
                    IF POSLine_l."Line No." = 41 THEN begin
                        IF POSSESSION.GetValue('FSNCREATEPREFAC') = 'TRUE' THEN BEGIN
                            IF POSTransaction_l.Get(PosTransGlobalC.GetReceiptNo()) THEN BEGIN
                                if ValCustomer.get(POSTransaction_l."Customer No.") then begin
                                    if ValCustomer."Phone No." <> '' then begin
                                        if not ComtactV.Get(ValCustomer."Phone No.") then begin
                                            ComtactV.Init;
                                            ComtactV.Validate("No.", ValCustomer."Phone No.");
                                            ComtactV."Phone No." := ValCustomer."Phone No.";
                                            ComtactV.Name := ValCustomer.Name;
                                            ComtactV."Name 2" := ValCustomer."Name 2";
                                            ComtactV."Search Name" := ValCustomer."Search Name";
                                            ComtactV."LSC Next Order Restaurant" := 'F20';
                                            ComtactV.Type := ComtactV.Type::Person;
                                            ComtactV.SetSkipDefault;
                                            ComtactV.Insert(true);
                                        end;
                                        WebServiceTableProceess(POSTransaction_l);
                                        IF WebTable.Get(POSTransaction_l."Receipt No.") THEN
                                            PG.SETGLOBALVALUE(WebTable);
                                        Commit();
                                        PG.RunModal();
                                    end else
                                        Message(TEXT006);
                                end else
                                    Message(TEXT005);
                            END;
                        END;

                        if POSSESSION.GetValue('PDAF') = 'TRUE' then begin
                            IF POSTransaction_l.Get(PosTransGlobalC.GetReceiptNo()) then
                                If POSTransaction_l."Customer No." <> '' then begin
                                    POSSESSION.SetValue('DEL-PickupDate', '');
                                    POSSESSION.SetValue('DEL-PickupTime', '');
                                    POSSESSION.SetValue('CURRORDER', POSTransaction_l."Receipt No.");
                                    POSSESSION.SetValue('PDAF', 'TRUE');
                                    CreateDeliveryOrder(POSTransaction_l);
                                    WebServiceTableProceess(POSTransaction_l);
                                    IF WebTable.Get(POSTransaction_l."Receipt No.") THEN
                                        PG.SETGLOBALVALUE(WebTable);
                                    Commit();
                                    PG.RunModal();
                                END;
                        end;
                    end;

                end;
            end;
    end;


    procedure CreateDeliveryOrder(POSTransaction: Record "LSC POS Transaction")
    var
        myInt: Integer;
        Delorder: Record "LSC Delivery Order";
        customer: Record Customer;
    begin
        Delorder.Reset();
        if POSTransaction."Customer No." <> '' then begin
            if customer.Get(POSTransaction."Customer No.") then;
            if not Delorder.Get(POSTransaction."Receipt No.") then begin
                Delorder.Init();
                Delorder."Order No." := POSTransaction."Receipt No.";
                Delorder."Phone No." := customer."Phone No.";
                Delorder.Name := customer.Name;
                Delorder."Order Date" := Today;
                Delorder."Contact Pickup Time" := Time;
                Delorder."Time Created" := Time;
                Delorder."Printed OK" := true;
                Delorder."Sales Type" := 'DELIVERY';
                Delorder."Assigned to Driver" := false;
                Delorder."Order Taker" := POSTransaction."Sales Staff";
                Delorder."Restaurant No." := POSTransaction."Store No.";
                Delorder."General Status" := Delorder."General Status"::"In Process";
                Delorder."Date Created" := Today;
                Delorder."Created at Call Center" := 'F20';
                Delorder.Insert(true);
            end;
        end;
    end;

    procedure InsertTmpTrans(var LastSlipNo: Code[20]; ShiftNo: Code[1]; SetSalesType: Code[20]; TableNo: Integer; TrainingActive: Boolean; TableDescr: Text) NewSlipNo: Code[20]
    var
        TmpTrans: Record "LSC POS Transaction";
        SalesTypes: Record "LSC Sales Type";
        Seq: Integer;
        LoopCount: Integer;
        InsertOK: Boolean;
        StoreSetup: Record "LSC Store";
        LocalizationExt: Codeunit "LSC Retail Localization Ext.";
        Text260: Label 'Table %1';
    begin

        StoreSetup.Get(POSSESSION.StoreNo);
        TmpTrans."Receipt No." := LastSlipNo;
        TmpTrans."New Transaction" := true;
        TmpTrans."Store No." := POSSESSION.StoreNo;
        TmpTrans."POS Terminal No." := POSSESSION.TerminalNo;
        TmpTrans."Created on POS Terminal" := POSSESSION.TerminalNo;
        TmpTrans."Staff ID" := POSSESSION.StaffID;
        TmpTrans."Shift No." := ShiftNo;
        TmpTrans."Gen. Bus. Posting Group" := StoreSetup."Store Gen. Bus. Post. Gr.";
        TmpTrans."VAT Bus.Posting Group" := StoreSetup."Store VAT Bus. Post. Gr.";
        if LocalizationExt.IsNALocalizationEnabled then begin
            TmpTrans."Tax Area Code" := StoreSetup."Tax Area Code";
            TmpTrans."Tax Liable" := StoreSetup."Tax Liable";
        end;
        TmpTrans."Sale Is Return Sale" := false;
        TmpTrans."Sales Type" := SetSalesType;
        TmpTrans."Table No." := TableNo;

        if TableNo <> 0 then
            TmpTrans.Comment := StrSubstNo(Text260, Format(TableNo));
        TmpTrans."Dining Tbl. Description" := TableDescr;

        TmpTrans."Entry Status" := TmpTrans."Entry Status"::Suspended;

        if SetSalesType <> '' then
            if SalesTypes.Get(SetSalesType) then begin
                if SalesTypes."VAT Bus. Posting Group" <> '' then
                    TmpTrans.Validate("VAT Bus.Posting Group", SalesTypes."VAT Bus. Posting Group");
                if SalesTypes."Price Group" <> '' then
                    TmpTrans.Validate(TmpTrans."Price Group Code", SalesTypes."Price Group");
            end;

        TmpTrans."Hosp. Type Sequence" := 0;
        if Evaluate(Seq, POSSESSION.GetValue('HOSTYPSEQ')) then
            TmpTrans."Hosp. Type Sequence" := Seq;
        TmpTrans.Insert;
        Commit;
        exit(TmpTrans."Receipt No.");
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
            POSSESSION.SetValue('FSNCREATEPREFAC', 'FALSE');
    end;

    procedure WebServiceTableProceess(POSTransaction: Record "LSC POS Transaction")
    var
        myInt: Integer;
        GlobalsCSWebServiceTable: Record "FSN WebServiceTable";
        Customer_l: Record Customer;
        StrPosint: integer;
    begin
        GlobalsCSWebServiceTable.Reset();
        if GlobalsCSWebServiceTable.Get(POSTransaction."Receipt No.") then begin
            //GlobalsCSWebServiceTable.LastSlipNo := POSTransaction."Receipt No.";
            GlobalsCSWebServiceTable.Store := POSTransaction."Store No.";
            GlobalsCSWebServiceTable.Terminal := POSTransaction."POS Terminal No.";
            //GlobalsCSWebServiceTable."Order Type" := GlobalsCSWebServiceTable."Order Type"::Delivery;
            GlobalsCSWebServiceTable."Order No." := '';
            GlobalsCSWebServiceTable.Date := TODAY;
            GlobalsCSWebServiceTable.Time := TIME;
            GlobalsCSWebServiceTable."Status WS" := GlobalsCSWebServiceTable."Status WS"::Pending;
            if POSSESSION.GetValue('FSNCREATEPREFAC') = 'TRUE' then
                GlobalsCSWebServiceTable."WS Request" := 'SEND_POSTRANS_BACKUP_BC';
            POSTransaction.CalcFields("Gross Amount");
            GlobalsCSWebServiceTable.Amount := POSTransaction."Gross Amount";
            GlobalsCSWebServiceTable."Customer No." := POSTransaction."Customer No.";
            IF Customer_l.GET(POSTransaction."Customer No.") THEN BEGIN
                GlobalsCSWebServiceTable."Sell-to Contact No." := Customer_l."Phone No.";
                GlobalsCSWebServiceTable.Mail := Customer_l."E-Mail";
                StrPosInt := STRPOS(Customer_l.Name, ' ');
                IF StrPosInt > 0 THEN BEGIN
                    GlobalsCSWebServiceTable."First Name" := COPYSTR(Customer_l.Name, 1, StrPosInt);
                    GlobalsCSWebServiceTable."Last Name" := COPYSTR(Customer_l.Name, StrPosInt, MAXSTRLEN(GlobalsCSWebServiceTable."Last Name"));
                END;
                IF Customer_l."FSN DUI" <> '' THEN BEGIN
                    GlobalsCSWebServiceTable."Document Personal" := Customer_l."FSN DUI";
                    GlobalsCSWebServiceTable."Document Type" := GlobalsCSWebServiceTable."Document Type"::DUI;
                END ELSE
                    IF Customer_l."FSN NRC" <> '' THEN BEGIN
                        GlobalsCSWebServiceTable."Document Personal" := Customer_l."FSN NRC";
                        GlobalsCSWebServiceTable."Document Type" := GlobalsCSWebServiceTable."Document Type"::NRC;
                    END;
            END;
            GlobalsCSWebServiceTable.Modify();
        end;
    end;


    [EventSubscriber(ObjectType::Table, Database::"LSC POS Transaction", 'OnBeforeModifyEvent', '', true, true)]
    local procedure "LSC POS Transaction_OnBeforeModifyEvent"
    (
        var Rec: Record "LSC POS Transaction";
        var xRec: Record "LSC POS Transaction";
        RunTrigger: Boolean
    )
    var
        TransinfoEntry: Record "LSC Trans. Infocode Entry";

    begin
        if Rec."Retrieved from Receipt No." <> '' then begin
            TransinfoEntry.Reset();
            TransinfoEntry.SetRange("Transaction No.", Rec."Retrieved from Trans. No.");
            TransinfoEntry.SetRange("POS Terminal No.", Rec."Retrieved from POS Term. No.");
            TransinfoEntry.SetRange("Store No.", Rec."Retrieved from Store No.");
            TransinfoEntry.SetRange(Infocode, 'NGUIA');
            if TransinfoEntry.FindFirst() then begin
                if StrLen(TransinfoEntry.Information) > 20 then begin
                    TransinfoEntry.Information := CopyStr(DelChr(TransinfoEntry.Information, '=', '-'), 1, 20);
                    TransinfoEntry.Modify(false);
                end;
            end;
        end;
    end;


    [EventSubscriber(ObjectType::Table, Database::"LSC POS Trans. Infocode Entry", 'OnBeforeInsertEvent', '', true, true)]
    local procedure "LSC POS Trans. Infocode Entry_OnBeforeInsertEvent"
    (
        var Rec: Record "LSC POS Trans. Infocode Entry";
        RunTrigger: Boolean
    )
    var
        NewPOSTransLine: Record "LSC POS Trans. Line";
        pPOSTransLine: Record "LSC POS Trans. Line";
        FreeTextRemesa: Label 'N° Remesa: %1';
        FreeTextStoreSelect: Label 'Tienda Selec: %1';
        pNextLine: Integer;
        PosTransInfoEntry: Record "LSC POS Trans. Infocode Entry";
        FSNWebTable: Record "FSN WebServiceTable";


    begin

        //Crea linea free text en pos trans Line con el numero de remesa
        if FSNWebTable.Get(Rec."Receipt No.") AND (FSNWebTable."WS Request" = 'SEND_POSTRANS_BACKUP_BC') then begin
            if Rec.Infocode IN ['NREMESA'] then begin
                pNextLine := 10000;
                pPOSTransLine.RESET;
                pPOSTransLine.SETCURRENTKEY("Receipt No.", "Line No.");
                pPOSTransLine.SETRANGE(pPOSTransLine."Receipt No.", Rec."Receipt No.");
                IF pPOSTransLine.FINDLAST THEN
                    pNextLine := pPOSTransLine."Line No." + 10000;

                NewPOSTransLine.Init();
                NewPOSTransLine."Receipt No." := Rec."Receipt No.";
                NewPOSTransLine."Store No." := Rec."Store No.";
                NewPOSTransLine."POS Terminal No." := Rec."POS Terminal No.";
                NewPOSTransLine."Entry Type" := NewPOSTransLine."Entry Type"::FreeText;
                NewPOSTransLine."Text Type" := NewPOSTransLine."Text Type"::"Freetext Input";
                NewPOSTransLine.Mark(true);
                NewPOSTransLine.VALIDATE(NewPOSTransLine.Description, STRSUBSTNO(FreeTextRemesa, Rec.Information));
                NewPOSTransLine."Line No." := pNextLine;
                Rec."New Entry Line No." := pNextLine;
                IF NewPOSTransLine.Insert(true) then;
            end;

            //Filtra free text de Numero de remesa para concatenar sala selecionada
            if Rec.Infocode IN ['OREFECT'] then begin
                PosTransInfoEntry.Reset();
                PosTransInfoEntry.SetRange(PosTransInfoEntry."Receipt No.", Rec."Receipt No.");
                PosTransInfoEntry.SetRange(PosTransInfoEntry."Transaction Type", PosTransInfoEntry."Transaction Type"::"Payment Entry");
                PosTransInfoEntry.SetRange(PosTransInfoEntry."Line No.", Rec."Line No.");
                PosTransInfoEntry.SetRange(PosTransInfoEntry.Infocode, 'NREMESA');
                if PosTransInfoEntry.FindFirst() then begin
                    pPOSTransLine.Reset();
                    pPOSTransLine.SetRange(pPOSTransLine."Receipt No.", Rec."Receipt No.");
                    pPOSTransLine.SetRange(pPOSTransLine."Entry Type", pPOSTransLine."Entry Type"::FreeText);
                    pPOSTransLine.SetRange(pPOSTransLine."Text Type", pPOSTransLine."Text Type"::"Freetext Input");
                    pPOSTransLine.SetRange(pPOSTransLine."Line No.", PosTransInfoEntry."New Entry Line No.");
                    if pPOSTransLine.FindFirst() then begin
                        pPOSTransLine.VALIDATE(pPOSTransLine.Description, pPOSTransLine.Description + ', ' + StrSubstNo(FreeTextStoreSelect, Rec.Information));
                        pPOSTransLine.Modify(true);
                        Rec."New Entry Line No." := pPOSTransLine."Line No.";
                    end;
                end;
            end;
        end;
    end;


    //Anula las lineas en pos trans Line y elimina infocodigos
    [EventSubscriber(ObjectType::Table, Database::"LSC POS Trans. Line", 'OnAfterVoidLine', '', true, true)]
    local procedure "LSC POS Trans. Line_OnAfterVoidLine"(var Rec: Record "LSC POS Trans. Line")
    var
        PosInfocode: Record "LSC POS Trans. Infocode Entry";
        FSNWebTable: Record "FSN WebServiceTable";
        VoidPosTransLine: Record "LSC POS Trans. Line";
    begin
        if FSNWebTable.Get(Rec."Receipt No.") AND (FSNWebTable."WS Request" = 'SEND_POSTRANS_BACKUP_BC') then begin
            PosInfocode.Reset();
            PosInfocode.SetRange("Receipt No.", Rec."Receipt No.");
            PosInfocode.SetRange("Transaction Type", PosInfocode."Transaction Type"::"Payment Entry");
            PosInfocode.SetRange("Line No.", Rec."Line No.");
            if PosInfocode.Find('-') then begin
                VoidPosTransLine.Reset();
                VoidPosTransLine.SetRange(VoidPosTransLine."Receipt No.", PosInfocode."Receipt No.");
                VoidPosTransLine.SetRange(VoidPosTransLine."Line No.", PosInfocode."New Entry Line No.");
                VoidPosTransLine.SetRange(VoidPosTransLine."Entry Status", VoidPosTransLine."Entry Status"::" ");
                if VoidPosTransLine.FindFirst() then
                    VoidPosTransLine.VoidLine();
                repeat
                    PosInfocode.Delete();
                until PosInfocode.Next() = 0;
            end;
        end;
    end;

    /*-----------------------------------------------------------------------*/
    //NUEVO PROCESO PARA ENVIAR A CALL CENTER
    [EventSubscriber(ObjectType::Table, Database::"LSC Posted Delivery Order", 'OnBeforeModifyEvent', '', true, true)]
    local procedure "LSC Posted Delivery Order_OnBeforeModifyEvent"
    (
        var Rec: Record "LSC Posted Delivery Order";
        var xRec: Record "LSC Posted Delivery Order";
        RunTrigger: Boolean
    )
    var
        TransactionHeader: Record "LSC Transaction Header";
        VoidedInfoCodeEntry: Record "LSC POS Voided Infoc Entry";
        InfoCodeEntry: Record "LSC Trans. Infocode Entry";
        fsnwebservicetable: Record "FSN WebServiceTable";
    begin
        IF Rec."General Status" = Rec."General Status"::Cancelled THEN BEGIN
            TransactionHeader.Reset();
            TransactionHeader.SetCurrentKey("Receipt No.");
            TransactionHeader.SetRange(TransactionHeader."Receipt No.", Rec."Order No.");
            IF TransactionHeader.FindLast() THEN begin
                ValInfoCancelCC(TransactionHeader);
                VoidedInfoCodeEntry.Reset();
                VoidedInfoCodeEntry.SetRange("Receipt No.", Rec."Order No.");
                if VoidedInfoCodeEntry.Find('-') then
                    repeat
                        InfoCodeEntry.TransferFields(VoidedInfoCodeEntry);
                        InfoCodeEntry."Transaction No." := TransactionHeader."Transaction No.";
                        InfoCodeEntry."POS Terminal No." := TransactionHeader."POS Terminal No.";
                        InfoCodeEntry.Date := TODAY();
                        InfoCodeEntry.Time := TIME();
                        if not InfoCodeEntry.Insert(true) then
                            InfoCodeEntry.Modify(true);
                    until VoidedInfoCodeEntry.Next() = 0;
            end;
        end;
    END;

    local procedure ValInfoCancelCC(TransHeader: Record "LSC Transaction Header")
    var
        myInt: Integer;
        VoidLine: Record "LSC POS Voided Trans. Line";
    begin
        VoidLine.Reset();
        VoidLine.SetRange("Receipt No.", TransHeader."Receipt No.");
        if VoidLine.Find('-') then
            repeat
                CopylineInfocode(VoidLine, TransHeader)
            until VoidLine.Next() = 0;
    end;

    [EventSubscriber(ObjectType::Table, Database::"LSC Posted Delivery Order", 'OnBeforeInsertEvent', '', true, true)]
    local procedure "LSC Posted Delivery Order_OnBeforeInsertEvent"
    (
        var Rec: Record "LSC Posted Delivery Order";
        RunTrigger: Boolean
    )
    var
        ws, WebS : Record "FSN WebServiceTable";
        POSGUI: Codeunit "LSC POS GUI";
        XMLRequest: Text;
        XMLResponse: Text;
        RequestID: Text[50];
        PosMenuLineTemp: Record "LSC POS Menu Line" Temporary;
        Processed: Boolean;
        MsgResult: Text;
        FSNUtility: Codeunit "FSN Utility";
        POStDeliveryOrder: Record "LSC Posted Delivery Order";
        DelOrder: Record "LSC Delivery Order";//call155
    begin
        ws.Reset();
        ws.SetRange(Date, Today());
        ws.SetRange("WS Request", '');
        ws.SetRange(LastSlipNo, Rec."Order No.");
        ws.SetRange("Status WS", ws."Status WS"::Pending);
        if ws.FindSet() then
            repeat
                RequestID := 'DEL-TRANSFSN';//Crea tabla de delivery trip a DAF
                XMLRequest := ws.LastSlipNo;
                MsgResult := '';
                FSNUtility.InvokeGlobalChannel(XMLRequest, XMLResponse, RequestID, PosMenuLineTemp, Processed, MsgResult);
                if DelOrder.Get(ws.LastSlipNo) then begin
                    if WebS.Get(ws.LastSlipNo) then begin
                        WebS."Status WS" := WebS."Status WS"::Send;
                        WebS.Modify(true);
                    end;
                end;
                if Rec."Rest. Web Service Status" = rec."Rest. Web Service Status"::"Not Used" then begin
                    Rec."Rest. Web Service Status" := Rec."Rest. Web Service Status"::"Finalized-Not Sent";
                end;
            until ws.Next() = 0;
    end;

}


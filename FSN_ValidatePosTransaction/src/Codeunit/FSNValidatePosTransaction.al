/// <summary>
/// Codeunit FSN Validate Pos Transaction (ID 50031).
/// </summary>
codeunit 50031 "FSN Validate Pos Transaction"
{
    TableNo = "LSC POS Menu Line";
    Permissions = TableData "Detailed Cust. Ledg. Entry" = rimd;

    trigger OnRun()
    begin
        GlobalPosMenuLine := Rec;
        ErrorText := '';
        _ExitOnly := FALSE;

        IF POSTrans.GET("Current-RECEIPT") THEN BEGIN
            SalesStaff_l := POSTrans."Sales Staff";

            POSTransC.GetCurrInput();
            case Command OF
                'MDP_DEVOLUCIONES':
                    CheckTenderReturnSale(POSTrans);
                'CONTROLLEDPRODUCT':
                    ControlledProductExec(Rec.Parameter);
                'UOM_BlOCKED':
                    UOMBlockedExec();

                //'GETBALANCEGIFT'://Se comento por si se llega a nesecitar
                //RunGiftcardBalance();
                ELSE
            end
        end;
    end;

    var
        Junta: Option JVPM,JVPO,JVPMV;
        XMLRequest: Text;
        XMLResponse: Text;
        RequestID: Text[50];
        PosMenuLineTemp: Record "LSC POS Menu Line" temporary;
        Processed: Boolean;
        MsgResult: text;
        GlobalPosMenuLine: Record "LSC POS Menu Line";
        Parametrosfsn: Record "FSN Parameter";
        POSTrans: Record "LSC POS Transaction";
        POSGUI: Codeunit "LSC POS GUI";
        Utility: Codeunit "FSN Utility";
        SalesStaff_l: Code[20];
        CurrInput_l: Text;
        POSTransC: Codeunit "LSC POS Transaction";
        ErrorText: text;
        _ExitOnly: Boolean;
        passControlledProduct: Boolean;
        Iscontrolled: Boolean;
        POSSession: Codeunit "LSC POS Session";
        Customer: Record Customer;
        POSOFFER: Codeunit "LSC POS Offer Ext. Utility";
        POSINFOCODE: Codeunit "LSC POS Infocode Utility";
        DataEntry: Record "LSC POS Data Entry";
        POSControler: Codeunit "LSC POS Controller";
        eposInterface: Codeunit "LSC POS Control Interface";
        PriceUtility: Codeunit "LSC POS Price Utility";
        ws: Codeunit "LSC Web Services";
        #region [HASH VARIABLES]
        PASS_ADMIN: Label 'PASS_ADMIN';
        CODEUNIT_ID: Label 'CodeUnitID';
        SET_UOM_VALUE: Label 'SET_UOM_VALUE';
        CURRENT_UOM: Label 'CURRENT_UOM';
        FSNUtility: Codeunit "FSN Utility";
    #endregion

    #region [Internal Procedure]
    //verifica si es delivery para bloquear 
    local procedure BlockEditDeliveryOrder(pREC: Record "LSC POS Transaction"; VAR pErrorText: Text; VAR pExitOnly: Boolean): Boolean
    var
        RetailSetup: Record "LSC Retail Setup";
        OfflineCC: Record "LSC Offline Call Center";
        ParametersVar_l: record "FSN Parameter";
        DeliveryOrder: Record "LSC Delivery Order";
        POSTransLine: Record "LSC POS Trans. Line";
        lText001: Label 'Cant permission for Edit Delivery Order';
    begin
        RetailSetup.Get();
        if not OfflineCC.Get(RetailSetup."Local Store No.") then begin
            IF DeliveryOrder.GET(pREC."Receipt No.") THEN BEGIN
                IF (DeliveryOrder."Order Type Option" = 4) THEN
                    EXIT(TRUE);

                IF NOT (ParametersVar_l.GET('DELIVERY', 'OK') AND ParametersVar_l.Activo) THEN BEGIN
                    pErrorText := lText001;
                    pExitOnly := FALSE;
                    POSSession.SetValue('FirstPass', 'false');
                    EXIT(FALSE);
                END;
            END;
        end;
        exit(true);
    end;

    //verifica si es un producto bloqueado de facturacion
    local procedure Tipologia0(pRec: Record "LSC POS Transaction"; VAR pErrorText: Text): Boolean
    var
        lText001: label 'Cant to invoice because is typology 0';
        transline: Record "LSC POS Trans. Line";
        FSNParameter: Record "FSN Parameter";
    begin
        transline.Reset();
        transline.SetCurrentKey("Receipt No.", "Entry Type", "Entry Status");
        transline.SetRange("Receipt No.", pRec."Receipt No.");
        transline.SetRange("Entry Type", transline."Entry Type"::Item);
        transline.setRange("Entry Status", transline."Entry Status"::" ");
        if transline.Find('-') then
            repeat
                FSNParameter.Reset();
                FSNParameter.SetCurrentKey(Grupo, codigo);
                FSNParameter.SetRange(Grupo, 'TPVBLOCK');
                FSNParameter.SetRange(codigo, transline.Number);
                if FSNParameter.FindFirst() then begin
                    pErrorText := lText001;
                    EXIT(true);
                end;
            until transline.next = 0;
        exit(false);
    end;

    local procedure ValidateControllledProduct(CurrInput: code[20]): Boolean
    var
        Infocode: Record "LSC Table Specific Infocode";
        Items: Record Item;
        ItemID: Code[20];
    begin
        Items.Reset();
        Items.SETRANGE("No.", CurrInput);
        if not items.FindFirst() then begin
            Items.Reset();
            items.SETRANGE("FSN Barcode No.", CurrInput);
            if not items.FindFirst() then begin
                POSSession.SetValue('ControlledProduct', 'no');
                exit(false);
            end;
        end;
        Items.Reset();
        Items.SETRANGE("FSN Barcode No.", CurrInput);
        if Items.FindFirst() then begin
            ItemID := Items."No.";
        end else begin
            ItemID := CurrInput;
        end;
        Infocode.Reset();
        Infocode.SETRANGE(Value, ItemID);
        Infocode.SETRANGE("Infocode Code", 'NRECETA');
        if Infocode.FindFirst() then begin//15837
            IF NOT ProductosContro(Items) then begin
                POSSession.SetValue(CODEUNIT_ID, '50031');
                POSSession.SetValue('ITEMLOGIN', ItemID);
                eposInterface.ShowPanelModal('#FSNLOGIN', 'CONTROLLEDPRODUCT');
                POSSession.SetValue('FirstPass', 'false');
            end;
            exit(true);
        end;
    end;

    local procedure ProductosContro(Items: Record Item): Boolean
    var
        myInt: Integer;
        PosTransLine2: Record "LSC POS Trans. Line";
        POSTransCC: Codeunit "LSC POS Transaction";
        Item: Record Item;
    begin
        PosTransLine2.Reset();
        PosTransLine2.SetRange("Receipt No.", POSTransCC.GetReceiptNo());
        PosTransLine2.SetRange("Entry Status", PosTransLine2."Entry Status"::" ");
        PosTransLine2.SetRange("Entry Type", PosTransLine2."Entry Type"::Item);
        if PosTransLine2.Find('-') then
            repeat
                Item.Reset();
                if Item.Get(PosTransLine2.Number) then
                    if (StrPos(Item."LSC Attrib 2 Code", 'CONTROL') > 0) and (Item."No." <> Items."No.") then begin
                        Message('No puede agregar más de un producto controlado');
                        EXIT(true);
                    end;
            until PosTransLine2.Next() = 0;
    end;

    local procedure ControlledProductExec(status: Text)
    var
        PostransCU: Codeunit "LSC POS Transaction";
    begin
        POSSession.SetValue(PASS_ADMIN, 'confirm');
        PostransCU.ItemNoPressed();
    end;

    local procedure UOMBlockedExec()
    var
        PostransCU: Codeunit "LSC POS Transaction";
        input: text;
    begin
        POSSession.SetValue(PASS_ADMIN, 'confirm');
        input := POSSession.GetValue('FSN_Barcode');
        PostransCU.ItemNoPressed();
    end;

    local procedure RecalculatePrices(CustomerNo: Code[20]; posTransaction: Record "LSC POS Transaction"; var handler: Boolean)
    var
        menuLine: Record "LSC POS Menu Line";
        posTransC: Codeunit "LSC POS Transaction";
    begin
        if posTransaction."Member Card No." <> '' then begin
            DeletCustomerL(posTransaction);
            //ValidateGroupDesc(posTransaction."Customer No.", posTransaction."Member Card No.");
            menuLine.Init();
            menuLine.Command := 'MEMBERCARD';
            menuLine.Parameter := posTransaction."Member Card No.";
            posTransC.run(menuLine);
        end else begin
            DeletCustomerL(posTransaction);
            menuLine.Init();
            menuLine.Command := 'SELECTCUST';
            menuLine.Parameter := CustomerNo;
            posTransC.run(menuLine);
        end;

        if not ValidateCustomer(posTransaction) then begin
            menuLine.Init();
            menuLine.Command := 'CANCEL';
            posTransC.run(menuLine);
        end;

        if (EvaluateIsNeedReAddCust(posTransaction)) then
            handler := true;
    end;

    local procedure DeletCustomerL(POSTransaction: Record "LSC POS Transaction")
    var
        myInt: Integer;
        POSTransLine: Record "LSC POS Trans. Line";
    begin
        POSTransLine.Reset();
        POSTransLine.SetRange("Receipt No.", POSTransaction."Receipt No.");
        POSTransLine.SetRange("Entry Type", POSTransLine."Entry Type"::FreeText);
        POSTransLine.SetFilter("Text Type", '=%1|%2', POSTransLine."Text Type"::"Cust. Text", POSTransLine."Text Type"::"Member Text");
        if POSTransLine.Find('-') then begin
            repeat
                if POSTransLine."Card/Customer/Coup.Item No" <> '' then
                    POSTransLine.Delete();
                Commit();
            until POSTransLine.Next() = 0;
        end;
    end;

    local procedure ValidateCustomer(POSTransaction: Record "LSC POS Transaction"): Boolean
    var
        myInt: Integer;
        POSTransLine: Record "LSC POS Trans. Line";
    begin
        POSTransLine.Reset();
        POSTransLine.SetRange("Receipt No.", POSTransaction."Receipt No.");
        POSTransLine.SetRange("Entry Type", POSTransLine."Entry Type"::FreeText);
        POSTransLine.SetFilter("Text Type", '=%1|%2', POSTransLine."Text Type"::"Cust. Text", POSTransLine."Text Type"::"Member Text");
        if POSTransLine.Find('-') then begin
            exit(true);
        end else
            exit(false);
    end;

    procedure ValidateGroupDesc(CustomerNo: Text[100]; Membresia: Text[100])
    var
        MemberShip: Record "LSC Membership Card";
        rMembersAccount: Record "LSC Member Account";
        Customer: Record Customer;
        schemeMebership: Record "LSC Member Scheme";
    begin
        if MemberShip.Get(Membresia) then
            IF rMembersAccount.GET(MemberShip."Account No.") THEN BEGIN
                if customer.get(rMembersAccount."Linked To Customer No.") then begin
                    if schemeMebership.Get(membership."Scheme Code") then
                        if (customer."Customer Disc. Group" <> schemeMebership."Default Cust. Disc. Group") and (schemeMebership."Default Cust. Disc. Group" <> '') then begin
                            customer."Customer Disc. Group" := schemeMebership."Default Cust. Disc. Group";
                            customer.Modify();
                        end;
                end;
            end;
    end;

    local procedure EvaluateIsNeedReAddCust(var POSTransaction: Record "LSC POS Transaction"): Boolean
    var
        posTransLine: Record "LSC Pos Trans. Line";
    begin
        posTransLine.SetCurrentKey("Receipt No.", "Line No.");
        posTransLine.SetRange("Receipt No.", POSTransaction."Receipt No.");
        posTransLine.SetRange("Entry Status", posTransLine."Entry Status"::" ");
        posTransLine.SetFilter(posTransLine."Entry Type", '=%1 | =%2', posTransLine."Entry Type"::Item, posTransLine."Entry Type"::FreeText);
        posTransLine.SetFilter("Entry Status", '=%1 | =%2', posTransLine."Text Type"::" ", posTransLine."Text Type"::"Cust. Text");
        if posTransLine.FindLast() then
            exit(posTransLine."Entry Type" = posTransLine."Entry Type"::Item);
    end;

    local procedure ValVATGroup(var POSTransaction: Record "LSC POS Transaction"): Boolean
    var
        posTransLine: Record "LSC Pos Trans. Line";
    begin
        posTransLine.SetCurrentKey("Receipt No.", "Line No.");
        posTransLine.SetRange("Receipt No.", POSTransaction."Receipt No.");
        posTransLine.SetRange("Entry Status", posTransLine."Entry Status"::" ");
        posTransLine.SetRange(posTransLine."Entry Type", posTransLine."Entry Type"::Item);
        posTransLine.SetFilter("VAT Amount", '<>%1', 0);
        posTransLine.SetFilter("Vat Bus. Posting Group", 'EXENTO');
        if posTransLine.FindLast() then
            exit(true);
    end;

    local procedure ValidateUniqueCoupon(CurrInput: Text; transaction: Record "LSC POS Transaction"): Boolean
    var
        input: Code[10];
        customer: Record Customer;
        coupon: Record "LSC Coupon Header";
    begin
        input := CopyStr(CurrInput, 1, 10);

        if not coupon.Get(input) then
            exit(false);

        if coupon."Price Group" <> 'FIDELIZAR' then
            exit(false);

        if not customer.Get(transaction."Customer No.") then begin
            Message('debe asignar un cliente primero');
            exit(true);
        end;

        if (customer."Chain Name" = CurrInput) then begin
            Message('El cupon ya fue utilizado o el cliente ya a utilizado un cupon');
            exit(true);
        end;

        customer."Chain Name" := CurrInput;
        customer.Modify(true);

        exit(false);
    end;

    local procedure checkSpecialCoupon(posTrans: Record "LSC POS Transaction")
    var
        coupon: Record "LSC Coupon Header";
        transLine: Record "LSC POS Trans. Line";
    begin
        transLine.SetRange("Receipt No.", posTrans."Receipt No.");
        transLine.SetRange("Entry Type", transLine."Entry Type"::Coupon);
        transLine.setRange("Entry Status", transLine."Entry Status"::" ");
        if transLine.FindSet() then
            repeat
                IF coupon.Get(transLine.Number) then
                    if coupon."Price Group" = 'FIDELIZAR' then begin
                        verifyCustomerCoupon(coupon.Code, posTrans."Customer No.");
                    end;
            until transLine.Next() = 0;
    end;

    local procedure verifyCustomerCoupon(Code: Code[10]; GetCustomerNo: Code[20])
    begin
        if GetCustomerNo <> '' then begin
            customer.Get(GetCustomerNo);
            if customer."Chain Name" <> Code then begin
                customer."Chain Name" := Code;
                customer.Modify(true);
            end;
        end;
    end;

    local procedure validateTransactionDiscount(): Boolean
    var
        customer, customer2 : Record Customer;
        posTrans: Record "LSC POS Transaction";
        menuLine: Record "LSC POS Menu Line";
        posTransCode: Codeunit "LSC POS Transaction";
        eposCtrl: Codeunit "LSC POS Control Interface";
    begin
        posTrans.Get(posTransCode.GetReceiptNo());

        if posTrans."customer Disc. Group" <> 'VIP' then
            exit(false);

        if not customer.Get(posTrans."Customer No.") then
            exit(false);


        if not (customer."Customer Disc. Group" = 'VIP') then
            exit(false);

        if customer."Customer Posting Group" = 'EMPLEADOS' then
            exit(false);

        if customer."Credit Limit (LCY)" = 0 then
            exit(false);

        customer."Customer Disc. Group" := 'RETAIL';
        customer.Modify(true);

        posTransCode.SelectCustPressed(posTrans."Customer No.");

        menuLine.Command := 'CANCEL2';
        posTransCode.run(menuLine);

        POSSession.SetValue('CHANGEGRO', 'TRUE');
        menuLine.Command := 'TOTAL';
        posTransCode.run(menuLine);

        IF customer2.Get(posTrans."Customer No.") then;
        customer2."Customer Disc. Group" := 'VIP';
        customer2.Modify(true);

        exit(true);
    end;

    local procedure showPanelMsg(msg: Text)
    var
        POSSession: Codeunit "LSC POS Session";
        PosTRansCode: Codeunit "LSC POS Transaction";
    begin
        POSSession.setValue('PaymentChange', msg);
        PosTRansCode.LookUp(true, 'CHANGE', '');
    end;

    local procedure ClientHaveCredit(var POSTransaction: Record "LSC POS Transaction"): Boolean
    var
        customer: Record Customer;
    begin
        if not customer.Get(POSTransaction."Customer No.") then
            exit(false);

        if (customer."Credit Limit (LCY)" = 0) then
            exit(false);

        if ((customer."Customer Posting Group" = 'EMPLEADOS') or (POSTransaction."Customer Disc. Group" <> 'VIP')) then
            exit(false);

        exit(true);
    end;

    local procedure getSQLInfo(var BillToCustomer: Record Customer; BilltoCustomerNo: Code[20])
    var
        query, con : Text;
        sqlConnection: DotNet SqlConnection;
        sqlCommand: DotNet SqlCommand;
        sqlDataReader: DotNet SqlDataReader;
        parameter: Record "FSN Parameter";
        distrLocation: Record "LSC Distribution Location";
        lTextConn: Label 'Data Source=%1;Initial Catalog=%2;Integrated Security=false; User ID=%3;Password=%4;';
    begin
        if parameter.Get('POS', 'CUST_BALANCE') and parameter.Activo then begin
            query := 'EXEC sp_getCustomerBalance ''' + BilltoCustomerNo + '''';
            if distrLocation.Get(parameter."Distribution Location Ext.") then;
            con := StrSubstNo(lTextConn, distrLocation."DB Server Name", distrLocation."Db. Path && Name", distrLocation."User ID", distrLocation.Password);
            sqlConnection := sqlConnection.SqlConnection(con);

            sqlConnection.Open();
            sqlCommand := sqlConnection.CreateCommand();
            sqlCommand.CommandText := query;

            sqlDataReader := sqlCommand.ExecuteReader();
            if sqlDataReader.Read() then begin
                BillToCustomer."LSC Amt. Charged On POS" := 0.0;
                BillToCustomer."LSC Amt. Charged Posted" := 0.0;
                BillToCustomer."Balance (LCY)" := SaldoRealCliente(sqlDataReader.GetDecimal(2), BilltoCustomerNo);
                BillToCustomer.MODIFY;
            end;
            sqlConnection.Close();
        end;
    end;

    local procedure SaldoRealCliente(SaldoServer: Decimal; BilltoCustomerNo: Code[20]): Decimal
    var
        Customer: Record Customer;
        PosTransLine: Record "LSC POS Trans. Line";
        Result: Action;
        ErrorText: Text;
        XMLRequest: Text;
        XMLResponse: Text;
        RequestID: Text[50];
        PosMenuLineTemp: Record "LSC POS Menu Line" temporary;
        Processed: Boolean;
        MsgResult: text;
        FSNUtility: Codeunit "FSN Utility";
        DeliveryOrder: Record "LSC Delivery Order";
        PosTrans: Codeunit "LSC POS Transaction";
    begin
        if Customer.Get(BilltoCustomerNo) then begin
            RequestID := 'FSNCC';
            Processed := false;
            FSNUtility.InvokeGlobalChannel(XMLRequest, XMLResponse, RequestID, PosMenuLineTemp, Processed, MsgResult);
            If Processed then begin
                PosTransLine.Reset();
                PosTransLine.SetRange("Card/Customer/Coup.Item No", BilltoCustomerNo);
                PosTransLine.SetRange(Number, '4');
                PosTransLine.SetRange("Entry Type", PosTransLine."Entry Type"::Payment);
                PosTransLine.SetRange("Entry Status", PosTransLine."Entry Status"::" ");
                PosTransLine.CalcSums(Amount);
            end else begin
                if DeliveryOrder.Get(PosTrans.GetReceiptNo()) then begin
                    PosTransLine.Reset();
                    PosTransLine.SetRange("Receipt No.", DeliveryOrder."Order No.");
                    PosTransLine.SetRange("Card/Customer/Coup.Item No", BilltoCustomerNo);
                    PosTransLine.SetRange(Number, '4');
                    PosTransLine.SetRange("Entry Type", PosTransLine."Entry Type"::Payment);
                    PosTransLine.SetRange("Entry Status", PosTransLine."Entry Status"::" ");
                    PosTransLine.CalcSums(Amount);
                end;
            end;
            SetCredictCust(Customer, SaldoServer + PosTransLine.Amount);
            exit(SaldoServer + PosTransLine.Amount);
        end;
    end;

    local procedure SetCredictCust(Customer: Record Customer; Saldo: Decimal)
    var
        parameter: Record "FSN Parameter";
        session: Codeunit "LSC POS Session";
        XMLRequest: Text;
        XMLResponse: Text;
        RequestID: Text[50];
        PosMenuLineTemp: Record "LSC POS Menu Line" temporary;
        Processed: Boolean;
        MsgResult: text;
        FSNUtility: Codeunit "FSN Utility";
        Tienda: Text;
        DetailC: Record "Detailed Cust. Ledg. Entry";
        Customer2, Customer3 : Record Customer;
    begin
        RequestID := 'FSNCC';
        Processed := false;
        FSNUtility.InvokeGlobalChannel(XMLRequest, XMLResponse, RequestID, PosMenuLineTemp, Processed, MsgResult);
        If Processed then
            Tienda := 'F20'
        ELSE
            Tienda := session.StoreNo();
        if parameter.Get('POS', 'CUST_BALANCE') and parameter.Activo then begin
            Customer.CalcFields("LSC Amt. Charged On POS");
            Customer.CalcFields("LSC Amt. Charged Posted");
            Customer.CalcFields("Balance (LCY)");
            SetCustBalance(Customer."No.", Customer."Global Dimension 1 Filter", Customer."Global Dimension 2 Filter", Customer."Currency Code", Saldo, Tienda);
        end;
    end;

    local procedure LoadToCalculateFields(Customer: Record Customer; payment: Decimal; Post: Boolean)
    var
        serverBalance: Decimal;
        Result: Action;
        XMLRequest: Text;
        XMLResponse: Text;
        RequestID: Text[50];
        PosMenuLineTemp: Record "LSC POS Menu Line" temporary;
        Processed: Boolean;
        MsgResult: text;
        FSNUtility: Codeunit "FSN Utility";
        Tienda: Text;
        parameter: Record "FSN Parameter";
        session: Codeunit "LSC POS Session";
    begin
        RequestID := 'FSNCC';
        Processed := false;
        FSNUtility.InvokeGlobalChannel(XMLRequest, XMLResponse, RequestID, PosMenuLineTemp, Processed, MsgResult);
        If Processed then
            Tienda := 'F20'
        ELSE
            Tienda := session.StoreNo();
        if parameter.Get('POS', 'CUST_BALANCE') and parameter.Activo then begin
            Customer.CalcFields("LSC Amt. Charged On POS");
            Customer.CalcFields("LSC Amt. Charged Posted");
            Customer.CalcFields("Balance (LCY)");
            if Post then
                serverBalance := (Abs(Customer."LSC Amt. Charged On POS") * -1) + Customer."Balance (LCY)"
            else
                serverBalance := Customer."Balance (LCY)";
            SetCustBalance(Customer."No.", Customer."Global Dimension 1 Filter", Customer."Global Dimension 2 Filter", Customer."Currency Code", serverBalance + payment, Tienda);
        end;
    end;

    procedure SetCustBalance(CustomerNo: Code[20]; Dimen1: Code[20]; Dimen2: Code[20]; CurrencyCode: Code[10]; Amount: Decimal; Terminal: Code[10])
    var
        DetailedCustLedgEntry: Record "Detailed Cust. Ledg. Entry";
        EntryNo: Integer;
        DocumentNo: Text[50];
        DeletedCustLedgEntry: Record "Detailed Cust. Ledg. Entry";
    begin
        // Generar el número de documento
        DocumentNo := 'PROV-' + Terminal;
        DeletedCustLedgEntry.Reset();
        DeletedCustLedgEntry.SetRange("Customer No.", CustomerNo);
        DeletedCustLedgEntry.SetFilter("Document No.", '<>%1', DocumentNo);
        DeletedCustLedgEntry.DeleteAll();
        // Verificar si ya existe un registro con el Document No_
        DetailedCustLedgEntry.Reset();
        DetailedCustLedgEntry.SetRange("Document No.", DocumentNo);
        if DetailedCustLedgEntry.FindSet() then begin
            // Actualizar el registro existente
            DetailedCustLedgEntry.Validate("Customer No.", CustomerNo);
            DetailedCustLedgEntry.Validate("Initial Entry Global Dim. 1", Dimen1);
            DetailedCustLedgEntry.Validate("Initial Entry Global Dim. 2", Dimen2);
            DetailedCustLedgEntry.Validate("Currency Code", CurrencyCode);
            DetailedCustLedgEntry.Validate("Amount (LCY)", Round(Amount, 0.01));
            DetailedCustLedgEntry.Validate("Posting Date", Today);
            DetailedCustLedgEntry.Modify();
        end else begin
            // Obtener el último Entry No_
            if DetailedCustLedgEntry.FindLast() then
                EntryNo := DetailedCustLedgEntry."Entry No." + 1
            else begin
                DetailedCustLedgEntry.Reset();
                DetailedCustLedgEntry.SetCurrentKey("Entry No.");
                if DetailedCustLedgEntry.FindLast() then begin
                    EntryNo := DetailedCustLedgEntry."Entry No." + 1
                end else begin
                    EntryNo := 1;
                end;
            end;
            // Insertar un nuevo registro
            DetailedCustLedgEntry.Init();
            DetailedCustLedgEntry."Entry No." := EntryNo;
            DetailedCustLedgEntry."Document No." := DocumentNo;
            DetailedCustLedgEntry.Validate("Customer No.", CustomerNo);
            DetailedCustLedgEntry.Validate("Initial Entry Global Dim. 1", Dimen1);
            DetailedCustLedgEntry.Validate("Initial Entry Global Dim. 2", Dimen2);
            DetailedCustLedgEntry.Validate("Currency Code", CurrencyCode);
            DetailedCustLedgEntry.Validate("Amount (LCY)", Round(Amount, 0.01));
            DetailedCustLedgEntry.Validate("Posting Date", Today);
            DetailedCustLedgEntry.Insert();
        end;
    end;
    #endregion 
    #region [External Procedure]

    procedure CheckInfocode(POSTransaction: Record "LSC POS Transaction"; CC: Boolean): Boolean
    var
        Infocode: Record "LSC Table Specific Infocode";
        TransLine: Record "LSC POS Trans. Line";
        Result: Action;
        NoReceta: Text[100];
        caption: Label 'RECETA: %1';
        MessageLabel: Label 'Numero de Receta es obligatorio para el producto %1, %2';
        MessageLabel2: Label 'Reafirmación de numero de receta es obligatorio para el producto %1, %2';
        POSInfocodeEntry: Record "LSC POS Trans. Infocode Entry";
        Item: Record "Item";
        Datime: DateTime;
        TableSpecInfocode: Record "LSC Table Specific Infocode";
        RecordID: Integer;
        POSMenulineTemp: Record "LSC POS Menu Line" temporary;
        POSTrC: Codeunit "LSC POS Transaction";
        InfoUtil: Codeunit "LSC POS Infocode Utility";
    begin
        IF NOT POSTransaction."Sale Is Return Sale" THEN BEGIN
            TransLine.RESET;
            TransLine.SETCURRENTKEY("Receipt No.", "Entry Type", "Entry Status");
            TransLine.SETRANGE("Receipt No.", POSTransaction."Receipt No.");
            TransLine.SETRANGE("Entry Type", TransLine."Entry Type"::Item);
            TransLine.SETRANGE("Entry Status", TransLine."Entry Status"::" ");
            if CC then begin
                TransLine.SetRange(TransLine.Number, POSSession.GetValue('ITEMLOGIN'));
                TransLine.SetRange(TransLine."Unit of Measure", POSSESSION.GetValue('VALUOMFSN'));
            end;
            IF TransLine.FIND('-') THEN
                REPEAT
                    IF Item.GET(TransLine.Number) THEN begin
                        TableSpecInfocode.SetCurrentKey("Table ID", Value, "Infocode Code");
                        TableSpecInfocode.SetRange(TableSpecInfocode."Table ID", Database::Item);
                        TableSpecInfocode.SetRange(TableSpecInfocode.Value, Item."No.");
                        TableSpecInfocode.SetRange(TableSpecInfocode."Infocode Code", 'NRECETA');
                        if TableSpecInfocode.FindFirst() then begin
                            POSInfocodeEntry.Reset();
                            POSInfocodeEntry.SetRange(POSInfocodeEntry."Receipt No.", TransLine."Receipt No.");
                            POSInfocodeEntry.SetRange(POSInfocodeEntry."Line No.", TransLine."Line No.");
                            POSInfocodeEntry.SetRange(POSInfocodeEntry.Infocode, TableSpecInfocode."Infocode Code");
                            if POSInfocodeEntry.FindFirst() then begin
                                IF POSInfocodeEntry.Subcode = '' THEN BEGIN
                                    Infocode.RESET;
                                    Infocode.SETCURRENTKEY("Table ID", Value, "Infocode Code");
                                    Infocode.SETRANGE(Value, TransLine.Number);
                                    Infocode.SETRANGE("Infocode Code", TableSpecInfocode."Infocode Code");
                                    IF Infocode.FINDFIRST THEN BEGIN
                                        POSSession.SetValue('#NoReceta', 'TRUE');
                                        POSSession.SetValue('#TransLineNoR', TransLine.Number);
                                        POSSession.SetValue('#LineNoR', Format(TransLine."Line No."));
                                        NoReceta := POSGUI.OpenAlphabeticKeyboard(CopyStr(StrSubstNo(caption, Item.Description), 1, 50), '', Result, true);
                                        if not CC then
                                            Message(StrSubstNo(MessageLabel2, TransLine.Number, TransLine.Description));
                                        exit(true);
                                    END;
                                end;
                            end else begin
                                POSSession.SetValue('#NoReceta', 'FALSE');
                                POSSession.SetValue('#NoRecetaCreate', 'TRUE');
                                POSSession.SetValue('#TransLineNoR', TransLine.Number);
                                POSSession.SetValue('#LineNoR', Format(TransLine."Line No."));
                                NoReceta := POSGUI.OpenAlphabeticKeyboard(CopyStr(StrSubstNo(caption, Item.Description), 1, 50), '', Result, true);
                                if not CC then
                                    Message(StrSubstNo(MessageLabel, TransLine.Number, TransLine.Description));
                                exit(true);
                            end;
                        end;
                    end;
                UNTIL TransLine.NEXT = 0;
        END;
        exit(false);
    end;

    procedure ConfirmReceta(POSTransaction: Record "LSC POS Transaction"): Boolean
    var
        myInt: Integer;
        Processedv: boolean;
        POSInfocodeEntry: Record "LSC POS Trans. Infocode Entry";
    begin
        RequestID := 'FSNCC';
        Processedv := false;
        FSNUtility.InvokeGlobalChannel(XMLRequest, XMLResponse, RequestID, PosMenuLineTemp, Processedv, MsgResult);
        If not Processedv then begin
            exit(CheckInfocode(POSTransaction, false));
        end else begin
            POSInfocodeEntry.Reset();
            POSInfocodeEntry.SetRange(POSInfocodeEntry."Receipt No.", POSTransaction."Receipt No.");
            POSInfocodeEntry.SetRange(POSInfocodeEntry.Infocode, 'NRECETA');
            if POSInfocodeEntry.FindFirst() then begin//030725
                IF POSInfocodeEntry.Subcode = '' THEN
                    exit(CheckInfocode(POSTransaction, false));
            end;
        end;
        exit(false);

    end;

    procedure VerifyAuthorizeControler(POSTransaction: Record "LSC POS Transaction"): Boolean
    var
        myInt: Integer;
        Infocode: Record "LSC Table Specific Infocode";
        Items: Record Item;
        POSTrnasLineValLog: Record "LSC POS Trans. Line";
        POSTransInfocodeEntry: Record "LSC POS Trans. Infocode Entry";
        MessageLabel2: Label 'Se requiere la clave de supervisor para el producto %1, %2';
        Processedv: boolean;
    begin

        IF NOT POSTransaction."Sale Is Return Sale" THEN BEGIN
            POSTrnasLineValLog.RESET;
            POSTrnasLineValLog.SETCURRENTKEY("Receipt No.", "Entry Type", "Entry Status");
            POSTrnasLineValLog.SETRANGE("Receipt No.", POSTransaction."Receipt No.");
            POSTrnasLineValLog.SETRANGE("Entry Type", POSTrnasLineValLog."Entry Type"::Item);
            POSTrnasLineValLog.SETRANGE("Entry Status", POSTrnasLineValLog."Entry Status"::" ");
            IF POSTrnasLineValLog.FIND('-') THEN
                REPEAT
                    if Items.Get(POSTrnasLineValLog.Number) then begin
                        Infocode.Reset();
                        Infocode.SETRANGE(Value, Items."No.");
                        Infocode.SETRANGE("Infocode Code", 'NRECETA');
                        if Infocode.FindFirst() then begin//030725
                            IF NOT ProductosContro(Items) then begin
                                POSTransInfocodeEntry.Reset();
                                POSTransInfocodeEntry.SetRange(POSTransInfocodeEntry."Receipt No.", POSTrnasLineValLog."Receipt No.");
                                POSTransInfocodeEntry.SetRange(POSTransInfocodeEntry."Transaction Type", 0);
                                POSTransInfocodeEntry.SetRange(POSTransInfocodeEntry.Infocode, 'LOGINAUTHORIZE');
                                POSTransInfocodeEntry.SetRange(POSTransInfocodeEntry."Source Code", Items."No.");
                                if not POSTransInfocodeEntry.FindFirst() then begin
                                    POSSession.SetValue(CODEUNIT_ID, '50031');
                                    POSSession.SetValue('ITEMLOGIN', Items."No.");
                                    POSSession.SetValue('TOTALOGIN', 'TRUE');
                                    POSSession.SetValue('ITEMUOMFSN', POSTrnasLineValLog.Number);
                                    POSSession.SetValue('VALUOMFSN', POSTrnasLineValLog."Unit of Measure");
                                    Message(StrSubstNo(MessageLabel2, POSTrnasLineValLog.Number, POSTrnasLineValLog.Description));
                                    eposInterface.ShowPanelModal('#FSNLOGIN', 'CONTROLLEDPRODUCT');
                                    POSSession.SetValue('FirstPass', 'false');
                                    exit(true);
                                end;
                            end;
                        end;
                    end;
                until POSTrnasLineValLog.next = 0;
        end;
        exit(false);
    end;

    [EventSubscriber(ObjectType::Table, Database::"LSC POS Trans. Infocode Entry", 'OnBeforeModifyEvent', '', true, true)]
    local procedure "LSC POS Trans. Infocode Entry_OnBeforeModifyEvent"
    (
        var Rec: Record "LSC POS Trans. Infocode Entry";
        var xRec: Record "LSC POS Trans. Infocode Entry";
        RunTrigger: Boolean
    )
    var
        NPOSTransaction: Record "LSC POS Transaction";
        Processedv: boolean;
    begin
        IF Rec.Infocode = 'NRECETA' then begin
            /*RequestID := 'FSNCC';
            Processedv := false;
            FSNUtility.InvokeGlobalChannel(XMLRequest, XMLResponse, RequestID, PosMenuLineTemp, Processedv, MsgResult);
            If Processedv then*/
            if NPOSTransaction.Get(Rec."Receipt No.") then//030725
                InsertLineReceta(NPOSTransaction, Rec.Information);
        END;
    end;

    procedure InsertLineReceta(posTransaB: Record "LSC POS Transaction"; Nreceta: text[100])
    var
        myInt: Integer;
        xPOStemp: Record "LSC POS Trans. Line";
    begin
        xPOStemp.Reset();
        xPOStemp.SetRange(xPOStemp."Store No.", posTransaB."Store No.");
        xPOStemp.SetRange(xPOStemp."POS Terminal No.", posTransaB."POS Terminal No.");
        xPOStemp.SetRange(xPOStemp."Receipt No.", posTransaB."Receipt No.");
        xPOStemp.SetRange(xPOStemp."Entry Type", xPOStemp."Entry Type"::FreeText);
        xPOStemp.SetRange(xPOStemp."Text Type", xPOStemp."Text Type"::"Freetext Input");
        if xPOStemp.Find('-') then begin
            repeat
                IF ((COPYSTR(xPOStemp.Description, 1, 9)) = 'N° RECETA') then begin
                    xPOStemp.Description := COPYSTR('N° RECETA : ' + Nreceta, 1, 50);
                    xPOStemp.Modify(true);
                    exit;
                end;
            until xPOStemp.next = 0;
        end;

        xPOStemp.INIT();
        xPOStemp."Store No." := posTransaB."Store No.";
        xPOStemp."POS Terminal No." := posTransaB."POS Terminal No.";
        xPOStemp."Receipt No." := posTransaB."Receipt No.";
        xPOStemp."Entry Type" := xPOStemp."Entry Type"::FreeText;
        xPOStemp."Line No." := LastPosTransLine(posTransaB) + 10000;
        xPOStemp."Entry Status" := 0;
        xPOStemp."Text Type" := xPOStemp."Text Type"::"Freetext Input";
        xPOStemp.Description := COPYSTR('N° RECETA : ' + Nreceta, 1, 50);
        if not xPOStemp.INSERT(TRUE) then
            xPOStemp.Modify(TRUE);
    end;

    procedure LastPosTransLine(posTransaB: Record "LSC POS Transaction"): Integer
    var
        xPOStemp: Record "LSC POS Trans. Line";
    begin
        xPOStemp.Reset();
        xPOStemp.SetRange(xPOStemp."Store No.", posTransaB."Store No.");
        xPOStemp.SetRange(xPOStemp."POS Terminal No.", posTransaB."POS Terminal No.");
        xPOStemp.SetRange(xPOStemp."Receipt No.", posTransaB."Receipt No.");
        if xPOStemp.FindLast() then
            exit(xPOStemp."Line No.");
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Controller", 'OnKeyboardResult', '', true, true)]
    local procedure "LSC POS Controller_OnKeyboardResult"
    (
        payload: Text;
        inputValue: Text;
        resultOK: Boolean;
        var processed: Boolean
    )
    var
        POSInfocodeEntry: Record "LSC POS Trans. Infocode Entry";
        POSTransaction: Codeunit "LSC POS Transaction";
        POSTransLine: Record "LSC POS Trans. Line";
        DateFilt: Date;
        TEXT000: Label 'N° Lote es obligatorio, Producto %1';
        TEXT001: Label 'N° Gif Card es obligatorio.';
        TEXT002: Label 'Saldo actual %1. Fecha Canducidad %2, Tipo de GiftCard %3';
        Item_l: Record Item;
        caption: label 'Ingrese Numero de lote:';
        Result: Action;
        EntryLineNo: Integer;
        infocoRec: Record "LSC Infocode";
        ProdDescription: Label '%1 %2';
        Canceled: Boolean;
        TSError: Boolean;
        ValueItemDescription: Text;
        TransLine: Record "LSC POS Trans. Line";
        POSInfocodeEntryC: Codeunit "LSC POS Infocode Utility";
        LineNoValue: Integer;
        messageText: Text;
        balance: Decimal;
        ExpiringDate: text;
        EntryType: Code[30];
    begin
        CLEAR(balance);
        CLEAR(ExpiringDate);
        CLEAR(EntryType);
        IF POSSession.GetValue('#NoReceta') = 'TRUE' THEN BEGIN
            POSInfocodeEntry.RESET;
            POSInfocodeEntry.SETCURRENTKEY("Receipt No.", Infocode, "Transaction Type", "Line No.");
            POSInfocodeEntry.SETRANGE("Receipt No.", POSTransaction.GetReceiptNo());
            POSInfocodeEntry.SETRANGE(Infocode, 'NRECETA');
            if Evaluate(LineNoValue, POSSession.GetValue('#LineNoR')) THEN;
            POSInfocodeEntry.SetRange(POSInfocodeEntry."Line No.", LineNoValue);
            POSInfocodeEntry.SETRANGE("Source Code", POSSession.GetValue('#TransLineNoR'));
            IF POSInfocodeEntry.FINDFIRST THEN BEGIN
                IF inputValue <> '' THEN BEGIN
                    POSInfocodeEntry.Information := inputValue;
                    POSInfocodeEntry.Subcode := 'CONFIRNRC';
                    POSInfocodeEntry.MODIFY;
                    POSSession.SetValue('#NRECETA', '');
                    POSSession.SetValue('#TransLineNoR', '');
                    processed := true;
                END ELSE BEGIN
                    POSSession.SetValue('#NRECETA', '');
                    POSSession.SetValue('#TransLineNoR', '');
                    processed := true;
                END;
            END;
        END;

        IF POSSession.GetValue('#NoRecetaCreate') = 'TRUE' THEN BEGIN
            IF resultOK THEN begin
                Canceled := false;
                TSError := false;
                EntryLineNo := 0;
                ValueItemDescription := StrSubstNo(ProdDescription, TransLine.Number, TransLine.Description);
                if Evaluate(LineNoValue, POSSession.GetValue('#LineNoR')) THEN;
                TransLine.Reset();
                TransLine.SetRange(TransLine."Receipt No.", POSTransaction.GetReceiptNo());
                TransLine.SetRange(TransLine."Entry Type", TransLine."Entry Type"::Item);
                TransLine.SetRange(TransLine."Line No.", LineNoValue);
                TransLine.SetRange(TransLine.Number, POSSession.GetValue('#TransLineNoR'));
                TransLine.SetRange(TransLine."Entry Status", TransLine."Entry Status"::" ");
                if TransLine.FindFirst() then begin
                    if infocoRec.Get('NRECETA') THEN//030725
                        POSInfocodeEntryC.IsInputOk(infocoRec, inputValue, ValueItemDescription, TransLine, Canceled, false, false, TSError, 0, '', '', false, 0, false, EntryLineNo);

                    POSInfocodeEntry.Reset();
                    POSInfocodeEntry.SetRange(POSInfocodeEntry."Receipt No.", TransLine."Receipt No.");
                    POSInfocodeEntry.SetRange(POSInfocodeEntry."Line No.", TransLine."Line No.");
                    POSInfocodeEntry.SetRange(POSInfocodeEntry.Infocode, 'NRECETA');
                    if POSInfocodeEntry.FindFirst() then begin
                        IF POSInfocodeEntry.Subcode = '' THEN BEGIN
                            POSInfocodeEntry.Subcode := 'CONFIRNRC';
                            POSInfocodeEntry.MODIFY;
                        END;
                    END;
                    POSSession.SetValue('#NoRecetaCreate', 'FALSE');
                    POSSession.SetValue('#LineNoR', '');
                    POSSession.SetValue('#TransLineNoR', '');
                end;
            end else begin
                POSSession.SetValue('#NoRecetaCreate', 'FALSE');
                POSSession.SetValue('#LineNoR', '');
                POSSession.SetValue('#TransLineNoR', '');
            end;
        end;

        IF POSSession.GetValue('#NOLOTE') <> '' THEN begin
            IF resultOK THEN BEGIN
                if Evaluate(LineNoValue, POSSession.GetValue('#NOLOTELINE')) THEN;
                ValPosTransLineCC(POSTransaction.GetReceiptNo(), CopyStr(inputValue, 1, 50), LineNoValue);
            END ELSE begin
                if Item_l.Get(POSSession.GetValue('#NOLOTE')) then;
                Message(StrSubstNo(TEXT000, Item_l."No."));
                POSGUI.OpenAlphabeticKeyboard(CopyStr(StrSubstNo(caption, Item_l.Description), 1, 50), '', Result, true);
            end;
        end;

        //PROCESS GIFTCAR CC
        if POSSession.GetValue('#GIFTPROCESS') = 'TRUE' THEN BEGIN
            IF resultOK THEN
                if inputValue <> '' then begin
                    inputValue := NormalizeGiftCardInput(inputValue);

                    if ValueFormatGiftCard(inputValue, messageText) then
                        ProcessGiftcardCC(inputValue)
                    else
                        Message(messageText);
                end else
                    Message(TEXT001);
            POSSession.SetValue('#GIFTLINE', '0');
            POSSession.SetValue('#GIFTPROCESS', 'FALSE');
        END;

        if POSSession.GetValue('#GIFTBALANCEPROCESS') = 'TRUE' THEN BEGIN
            IF resultOK THEN
                if inputValue <> '' then begin
                    inputValue := NormalizeGiftCardInput(inputValue);
                    ConsultationGiftcard(inputValue, balance, ExpiringDate, EntryType);
                    Message(StrSubstNo(TEXT002, Format(balance), Format(ExpiringDate), EntryType));
                end;
            POSSession.SetValue('#GIFTBALANCEPROCESS', 'FALSE');
        end;

    end;

    procedure ValueFormatGiftCard(InputValue: text; var MessageText: Text): boolean
    var
        Regex: DotNet Regex;
        Patron: Text;
        ValText000: Label 'No se permiten espacios ni caracteres especiales.';
        ValText001: label 'El valor debe tener más de 5 caracteres.';
    begin
        // Expresión regular: solo letras y números sin espacios ni símbolos
        Patron := '^[a-zA-Z0-9]+$';
        Regex := Regex.Regex(Patron);
        MessageText := '';

        if StrLen(InputValue) <= 5 then begin
            MessageText := ValText001;
            exit(false);
        end;

        if not Regex.IsMatch(InputValue) then begin
            MessageText := ValText000;
            exit(false);
        end;

        exit(true);
    end;

    local procedure NormalizeGiftCardInput(InputValue: Text): Text
    begin
        if CopyStr(UpperCase(InputValue), 1, 2) = 'GC' then
            exit(InputValue);

        if (CopyStr(InputValue, 1, 3) = '214') or (CopyStr(InputValue, 1, 3) = '215') then
            exit('GC' + InputValue);

        exit(InputValue);
    end;

    procedure ValPosTransLineCC(Recept: Code[20]; Lotno: text[50]; Line: Integer)
    var
        POSTransLine: Record "LSC POS Trans. Line";
        TransSalesEntry: Record "LSC Trans. Sales Entry";
        Datime: DateTime;
        Item_l: Record item;
        caption: Label 'Expire Date:';
        Result: Action;
        ErrorText: Text;
        XMLRequest: Text;
        XMLResponse: Text;
        RequestID: Text[50];
        PosMenuLineTemp: Record "LSC POS Menu Line" temporary;
        Processed: Boolean;
        MsgResult: text;
        FSNUtility: Codeunit "FSN Utility";
    begin
        POSTransLine.Reset();//28981 -2
        POSTransLine.SETRANGE(POSTransLine."Receipt No.", Recept);
        POSTransLine.SETRANGE(POSTransLine."Entry Type", POSTransLine."Entry Type"::Item);
        POSTransLine.SETRANGE(POSTransLine.Number, POSSession.GetValue('#NOLOTE'));
        POSTransLine.SETRANGE(POSTransLine."Line No.", Line);
        POSTransLine.SETFILTER(POSTransLine."Entry Status", '<>%1', POSTransLine."Entry Status"::Voided);
        if POSTransLine.FindFirst() then begin
            POSTransLine."Lot No." := Lotno;
            POSTransLine.Modify(TRUE);

            TransSalesEntry.Reset();
            TransSalesEntry.SetCurrentKey("Item No.", "Variant Code", Date, "Store No.", "Serial No.", "Lot No.");
            TransSalesEntry.SetRange(TransSalesEntry."Store No.", POSTransLine."Store No.");
            TransSalesEntry.SetRange(TransSalesEntry."Item No.", POSTransLine.Number);
            TransSalesEntry.SetFilter(TransSalesEntry."Lot No.", POSTransLine."Lot No.");
            IF TransSalesEntry.FindFirst() THEN begin
                POSTransLine."Expiration Date" := TransSalesEntry."Expiration Date";
                POSTransLine.Modify(TRUE);
                POSSession.SetValue('#NOLOTE', '');
                POSSession.SetValue('#NOLOTELINE', '');
            end ELSE BEGIN
                RequestID := '#RUNPAGELOT';//Exten. FSN_InsureCompany
                Processed := false;
                XMLRequest := POSSession.SetValue('#NOLOTE', POSTransLine.Number);
                XMLResponse := POSTransLine."Receipt No.";
                MsgResult := format(POSTransLine."Line No.");
                FSNUtility.InvokeGlobalChannel(XMLRequest, XMLResponse, RequestID, PosMenuLineTemp, Processed, MsgResult);
            END;
        end;
    end;


    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Controller", 'OnCalendarResult', '', true, true)]
    local procedure "LSC POS Controller_OnCalendarResult"
    (
        payload: Text;
        inputValue: DateTime;
        resultOK: Boolean;
        var processed: Boolean
    )
    var
        POSTransLine: Record "LSC POS Trans. Line";
        POSTransaction: Codeunit "LSC POS Transaction";
        NewDate: Date;
        Datime: DateTime;
        Item_l: Record item;
        caption: Label 'Expire Date:';
        Result: Action;
        TEXT000: Label 'La fecha es obligatoria, Producto %1';
    begin
        /*IF POSSession.GetValue('#NOLOTE') <> '' THEN begin
            if resultOK then begin
                POSTransLine.Reset();//28981 -3
                POSTransLine.SETRANGE(POSTransLine."Receipt No.", POSTransaction.GetReceiptNo());
                POSTransLine.SETRANGE(POSTransLine."Entry Type", POSTransLine."Entry Type"::Item);
                POSTransLine.SETRANGE(POSTransLine.Number, POSSession.GetValue('#NOLOTE'));
                POSTransLine.SETFILTER(POSTransLine."Entry Status", '<>%1', POSTransLine."Entry Status"::Voided);
                if POSTransLine.FindFirst() then begin
                    IF Evaluate(NewDate, Format(inputValue)) THEN BEGIN
                        POSTransLine."Expiration Date" := NewDate;
                        POSTransLine.Modify(TRUE);
                    END;
                end;
                POSSession.SetValue('#NOLOTE', '');
            end else begin
                POSTransLine.Reset();//28981
                POSTransLine.SETRANGE(POSTransLine."Receipt No.", POSTransaction.GetReceiptNo());
                POSTransLine.SETRANGE(POSTransLine."Entry Type", POSTransLine."Entry Type"::Item);
                POSTransLine.SETRANGE(POSTransLine.Number, POSSession.GetValue('#NOLOTE'));
                POSTransLine.SETFILTER(POSTransLine."Entry Status", '<>%1', POSTransLine."Entry Status"::Voided);
                if POSTransLine.FindFirst() then begin
                    if POSTransLine."Lot No." <> '' then begin
                        if Item_l.Get(POSSession.GetValue('#NOLOTE')) then;
                        Message(StrSubstNo(TEXT000, Item_l."No."));
                        POSGUI.OpenCalendar(CopyStr(StrSubstNo(caption, Item_l.Description), 1, 50), Datime, Result);
                    end;
                end ELSE
                    POSSession.SetValue('#NOLOTE', '');
            end;
        end;*/
    end;

    procedure ValidateExpireDate(POSTrans: Record "LSC POS Transaction"): Boolean
    var
        myInt: Integer;
        POSTransLine: Record "LSC POS Trans. Line";
        DateFilt: date;
        Datime: DateTime;
        Item_l: Record item;
        caption: Label 'Expire Date:';
        captionLote: Label 'Ingrese numero de Lote:';
        Result: Action;
        TEXT000: Label 'La fecha es obligatoria para N° Lote %1, Producto %2';
        TEXT001: Label 'N° Lote es obligatorio, Producto %1';
        ErrorText: Text;
        XMLRequest: Text;
        XMLResponse: Text;
        RequestID: Text[50];
        PosMenuLineTemp: Record "LSC POS Menu Line" temporary;
        Processed: Boolean;
        MsgResult: text;
        FSNUtility: Codeunit "FSN Utility";
    begin

        RequestID := 'FSNCC';
        Processed := false;
        FSNUtility.InvokeGlobalChannel(XMLRequest, XMLResponse, RequestID, PosMenuLineTemp, Processed, MsgResult);
        If NOT Processed then begin
            if Evaluate(DateFilt, '') then;
            POSTransLine.Reset();//28981 -4
            POSTransLine.SETRANGE(POSTransLine."Store No.", POSTrans."Store No.");
            POSTransLine.SETRANGE(POSTransLine."POS Terminal No.", POSTrans."POS Terminal No.");
            POSTransLine.SETRANGE(POSTransLine."Receipt No.", POSTrans."Receipt No.");
            POSTransLine.SETRANGE(POSTransLine."Entry Type", POSTransLine."Entry Type"::Item);
            POSTransLine.SETFILTER(POSTransLine."Entry Status", '<>%1', POSTransLine."Entry Status"::Voided);
            if POSTransLine.Find('-') then begin
                repeat
                    if not (POSTransLine."Lot No." in ['', '#LOTCOMODIN']) then begin
                        if (POSTransLine."Expiration Date" = DateFilt) then begin
                            if Item_l.Get(POSTransLine.Number) then;
                            POSSession.SetValue('#NOLOTE', Item_l."No.");
                            Message(StrSubstNo(TEXT000, POSTransLine."Lot No.", Item_l."No."));
                            XMLRequest := POSSession.GetValue('#NOLOTE');
                            XMLResponse := POSTransLine."Receipt No.";
                            RequestID := '#RUNPAGELOT';//Exten. FSN_InsureCompany
                            MsgResult := format(POSTransLine."Line No.");
                            FSNUtility.InvokeGlobalChannel(XMLRequest, XMLResponse, RequestID, PosMenuLineTemp, Processed, MsgResult);
                            //POSGUI.OpenCalendar(CopyStr(StrSubstNo(caption, Item_l.Description), 1, 50), Datime, Result);
                            exit(true);
                        end;
                    end else begin
                        POSSession.SetValue('#NOLOTELINE', '');
                        POSSession.SetValue('#NOLOTE', '');
                        if Item_l.Get(POSTransLine.Number) then
                            if (Item_l."Item Tracking Code" <> '') and (POSTransLine."Lot No." = '') then begin
                                POSSession.SetValue('#NOLOTE', Item_l."No.");
                                POSSession.SetValue('#NOLOTELINE', Format(POSTransLine."Line No."));
                                Message(StrSubstNo(TEXT001, Item_l."No."));
                                POSGUI.OpenAlphabeticKeyboard(CopyStr(StrSubstNo(captionLote, Item_l.Description), 1, 50), '', Result, true);
                                exit(true);
                            end;
                    end;
                until POSTransLine.Next() = 0;
            end;
        END;
        exit(false);
    end;

    procedure CheckTracker(POSTransaction: Record "LSC POS Transaction"; var MenuLine: Record "LSC POS Menu Line")
    var
        POSTransactionC: Codeunit "LSC POS Transaction";
        FSNParameter: Record "FSN Parameter";
        TransLine: Record "LSC POS Trans. Line";
        POSTransInfocode: Record "LSC POS Trans. Infocode Entry";
        _FSNParameter: Record "FSN Parameter";
    begin
        _FSNParameter.RESET;
        _FSNParameter.SETCURRENTKEY(Grupo, Codigo);
        _FSNParameter.SETRANGE(Grupo, 'STARTSHIP');
        _FSNParameter.SETRANGE(Codigo, 'INFOCODE');
        IF _FSNParameter.FINDFIRST THEN;


        TransLine.RESET;
        TransLine.SETCURRENTKEY("Receipt No.", "Entry Type", "Entry Status");
        TransLine.SETRANGE("Receipt No.", POSTransaction."Receipt No.");
        TransLine.SETRANGE("Entry Type", TransLine."Entry Type"::Item);
        TransLine.SETRANGE("Entry Status", TransLine."Entry Status"::" ");
        IF TransLine.FIND('-') THEN
            REPEAT
                FSNParameter.RESET;
                FSNParameter.SETCURRENTKEY(Grupo, Codigo);
                FSNParameter.SETRANGE(Grupo, 'STARTSHIP');
                FSNParameter.SETRANGE(Codigo, TransLine.Number);
                IF (FSNParameter.FINDFIRST) AND (FSNParameter.Activo) THEN BEGIN
                    POSTransInfocode.RESET;
                    POSTransInfocode.SETCURRENTKEY("Receipt No.", Infocode, "Transaction Type", "Line No.");
                    POSTransInfocode.SETRANGE("Receipt No.", POSTransaction."Receipt No.");
                    POSTransInfocode.SETRANGE(Infocode, _FSNParameter.Valor);
                    IF POSTransInfocode.FINDFIRST THEN BEGIN
                        EXIT;
                    END;

                    MenuLine."Post Command" := 'INFO_K';
                    MenuLine."Post Parameter" := _FSNParameter.Valor;
                    EXIT;
                END;
            UNTIL TransLine.NEXT = 0;


        POSTransInfocode.RESET;
        POSTransInfocode.SETCURRENTKEY("Receipt No.", Infocode, "Transaction Type", "Line No.");
        POSTransInfocode.SETRANGE("Receipt No.", POSTransaction."Receipt No.");
        POSTransInfocode.SETRANGE(Infocode, _FSNParameter.Valor);
        IF POSTransInfocode.FINDFIRST THEN BEGIN
            POSTransInfocode.DELETE;
            EXIT;
        END;
    end;

    procedure ValidateCustomer(Customer: Record Customer; MgrKey: Boolean; RefundSale: Boolean; Payment: Decimal; var ErrorText: Text; CalcN: Boolean): Boolean
    var
        TmpCustomer: Record Customer temporary;
        BillToCustomer: Record Customer;
        PosFuncProfile: Record "LSC POS Func. Profile";
        TSUtil: Codeunit "LSC POS Trans. Server Utility";
        POSFunct: Codeunit "LSC POS Functions";
        Text058: Label 'Connection to Transaction server failed.\Contact Manager.';
        Text049: Label 'Customer %1 is blocked';
        Text050: Label 'El cliente %1 esta por encima del limite de crédito ';
        Text001: Label 'El cliente %1 no posee crédito ';
        Text051: Label 'Customer %1 is over credit limit. Want to continue?';
        Sign: Decimal;
        CBalanceOverLimit: Decimal;
        ExitValue: boolean;
        IsHandled: boolean;
        Parametro: Record "FSN Parameter";
        DeTalCust: Record "Detailed Cust. Ledg. Entry";
    begin
        POSSESSION.SetValue('#CHARGEDONPOS', 'false');
        PosFuncProfile.RESET;
        IF PosFuncProfile.Get('#FASANI') THEN
            if PosFuncProfile."TS Customer" then begin
                if TSUtil.GetCustomer(TmpCustomer, Customer."No.", ErrorText) then begin
                    Customer := TmpCustomer
                end
                else
                    if (ErrorText <> '') and not MgrKey then begin
                        ErrorText := Text058;
                        exit(false);
                    end;
            end else begin
                getSQLInfo(Customer, Customer."No.");
            end;

        if (Customer."Bill-to Customer No." <> '') and (Customer."Bill-to Customer No." <> Customer."No.") then begin
            if PosFuncProfile."TS Customer" then begin
                if TSUtil.GetCustomer(TmpCustomer, Customer."Bill-to Customer No.", ErrorText) then
                    BillToCustomer := TmpCustomer
                else
                    if (ErrorText <> '') and not MgrKey then begin
                        ErrorText := Text058;
                        exit(false);
                    end;
            end else begin
                getSQLInfo(BillToCustomer, Customer."Bill-to Customer No.");
            end;
            Customer."LSC Other Tender in Finalizing" := BillToCustomer."LSC Other Tender in Finalizing";
            if BillToCustomer.Blocked.AsInteger() <> 0 then begin
                ErrorText := StrSubstNo(Text049, BillToCustomer."No.");
                exit(false);
            end;
            if RefundSale then
                Sign := -1
            else
                Sign := 1;
            if (Payment * Sign) <= 0 then
                exit(true);
            if BillToCustomer."Credit Limit (LCY)" <> 0 then begin
                CBalanceOverLimit := (BillToCustomer."Balance (LCY)" + Customer."LSC Amt. Charged On POS" + BillToCustomer."LSC Amt. Charged On POS" - Customer."LSC Amt. Charged Posted" - BillToCustomer."LSC Amt. Charged Posted" + Payment) - BillToCustomer."Credit Limit (LCY)";
                if CBalanceOverLimit > 0 then begin
                    if not MgrKey then begin
                        ErrorText := StrSubstNo(Text050, Customer."Bill-to Customer No.");
                        //Lista de transacciones pendientes
                        exit(false);
                    end else begin
                        ErrorText := StrSubstNo(Text050, Customer."Bill-to Customer No.");
                        exit(false);
                    end;
                end;
            end;
            //TODO: Modificar los registro de la tabla para el calcFields
            if CalcN then
                LoadToCalculateFields(BillToCustomer, 0.0, CalcN);
            exit(true);
        end;

        if Customer.Blocked.AsInteger() <> 0 then begin
            ErrorText := StrSubstNo(Text049, Customer."No.");
            exit(false);
        end;
        if RefundSale then
            Sign := -1
        else
            Sign := 1;
        if (Payment * Sign) <= 0 then
            exit(true);
        if Customer."Credit Limit (LCY)" <> 0 then begin
            CBalanceOverLimit := (Customer."Balance (LCY)" + Customer."LSC Amt. Charged On POS" - Customer."LSC Amt. Charged Posted" + Payment) - Customer."Credit Limit (LCY)";
            if CBalanceOverLimit > 0 then begin
                if not MgrKey then begin
                    ErrorText := StrSubstNo(Text050, Customer."No.");
                    ErrorText += SaldoCliente(Customer."No.");
                    exit(false);
                end;
                if not POSGUI.PosConfirm(StrSubstNo(Text051, Customer."No.", CBalanceOverLimit), false) then begin
                    ErrorText := StrSubstNo(Text050, Customer."No.");
                    exit(false);
                end;
            end;
        end else begin
            ErrorText := StrSubstNo(Text001, Customer."No.");
            exit(false);
        end;
        if (not (PosFuncProfile."TS Customer")) and (CalcN) then
            LoadToCalculateFields(Customer, 0.0, CalcN);
        exit(true);
    end;

    local procedure SaldoCliente(BilltoCustomerNo: Code[20]): Text
    var
        Customer: Record Customer;
        PosTransLine: Record "LSC POS Trans. Line";
        Mesagge: Text;
        Result: Action;
        ErrorText: Text;
        Tienda: Text;
    begin
        RequestID := 'FSNCC';
        Processed := false;
        FSNUtility.InvokeGlobalChannel(XMLRequest, XMLResponse, RequestID, PosMenuLineTemp, Processed, MsgResult);
        If Processed then begin
            if Customer.Get(BilltoCustomerNo) then begin
                PosTransLine.Reset();
                PosTransLine.SetRange("Card/Customer/Coup.Item No", BilltoCustomerNo);
                PosTransLine.SetRange(Number, '4');
                PosTransLine.SetRange("Entry Type", PosTransLine."Entry Type"::Payment);
                PosTransLine.SetRange("Entry Status", PosTransLine."Entry Status"::" ");
                if PosTransLine.Find('-') then
                    repeat
                        Mesagge += '\' + PosTransLine."Receipt No." + ' Por el monto $ ' + Format(PosTransLine.Amount);
                    until PosTransLine.Next() = 0;
                if Mesagge <> '' then
                    exit(StrSubstNo('\ %1 \Tiene transacciones pendientes de facturar: %2', Customer.Name, Mesagge));
            end;
        end;
    end;

    //Valida si es permitido cambiar Cliente
    procedure ValidateChangeCustomerORMember(POSTrans_l: Record "LSC POS Transaction"; CurrentInput_l: Text; _OptionInput_l: Option Customer,MembershipCard) VerifyOk: Boolean
    var
        TransLineVerify: Record "LSC POS Trans. Line";
        lText001: Label 'No puede cambiar al cliente porque ya existe una media de pago definida.';
    begin
        IF ((_OptionInput_l = _OptionInput_l::Customer) AND (CurrentInput_l <> POSTrans_l."Customer No.") AND (CurrentInput_l <> '')) OR
          (_OptionInput_l = _OptionInput_l::MembershipCard) THEN BEGIN
            CLEAR(TransLineVerify);
            TransLineVerify.RESET;
            TransLineVerify.SETCURRENTKEY("Receipt No.", "Entry Type", "Entry Status");
            TransLineVerify.SETRANGE(TransLineVerify."Receipt No.", POSTrans_l."Receipt No.");
            TransLineVerify.SETRANGE(TransLineVerify."Entry Type", TransLineVerify."Entry Type"::Payment);
            TransLineVerify.SETFILTER(TransLineVerify."Entry Status", '<>%1', TransLineVerify."Entry Status"::Voided);
            IF TransLineVerify.FINDFIRST THEN
                ERROR(lText001);
        END;
        EXIT(TRUE);
    end;

    procedure ValidateItemPendingScann(POSTransaction: Record "LSC POS Transaction"; ItemNo: Code[20]; UnitofMeasureCoe: Code[10]; TenderTypeCode: Code[10]; SalesStaffID: Code[20]; var ErrorText: Text[250]; var ExitOnly: Boolean): Boolean
    var
        POSTransLine_l: Record "LSC POS Trans. Line";
        lText001: Label 'Cant add item %1 ';
        Item_l, Item_ : Record Item;
        Barcodes_l: Record "LSC Barcodes";
        ItemNo2: Code[20];
        Description: Text[50];
        lText002: Label 'No se encontraron lineas pendientes';
        CountUnit: Integer;
        ItemUnitofMeasure: Record "Item Unit of Measure";
        PosFunc: codeunit "LSC POS Functions";
        ErrorT: Text;
        caption: Label 'No Lote:';
        Result: Action;
        Datime: DateTime;
    begin
        IF ItemNo = '' THEN
            EXIT(TRUE);

        IF NOT LinePendingConfirmScannExists(POSTransaction."Receipt No.") THEN BEGIN
            ExitOnly := true;
            EXIT(false);
        end else begin
            ExitOnly := FALSE;
        end;

        ItemNo2 := ItemNo;
        IF NOT Item_l.GET(ItemNo) THEN BEGIN
            IF Barcodes_l.GET(ItemNo) THEN BEGIN
                ItemNo := Barcodes_l."Item No.";
                Description := Barcodes_l.Description;
            END;
        END ELSE
            Description := Item_l.Description;

        POSTransLine_l.RESET;
        POSTransLine_l.SETCURRENTKEY("Receipt No.", "Entry Type", Number, "Variant Code", "Unit of Measure", "Entry Status");
        POSTransLine_l.SETRANGE(POSTransLine_l."Receipt No.", POSTransaction."Receipt No.");
        POSTransLine_l.SETRANGE(POSTransLine_l."Entry Type", POSTransLine_l."Entry Type"::Item);
        POSTransLine_l.SETRANGE(POSTransLine_l.Number, ItemNo);
        POSTransLine_l.SETFILTER(POSTransLine_l."Entry Status", '<>%1', POSTransLine_l."Entry Status"::Voided);
        POSTransLine_l.SETRANGE(POSTransLine_l."FSN Additional Action", POSTransLine_l."FSN Additional Action"::ConfirmScann);
        IF POSTransLine_l.FindFirst THEN begin
            if Item_.Get(POSTransLine_l.Number) then
                if (POSTransLine_l."Lot No." IN ['', '#LOTCOMODIN']) AND (Item_."Item Tracking Code" <> '') then begin
                    POSSession.SetValue('#NOLOTE', Item_."No.");//28981 -1
                    POSGUI.OpenAlphabeticKeyboard(CopyStr(StrSubstNo(caption, Item_.Description), 1, 50), '', Result, true);
                end;
            IF POSTransLine_l."FSN QuantityScan" <> POSTransLine_l.Quantity THEN BEGIN
                IF Item_l.GET(POSTransLine_l.Number) THEN
                    ItemUnitofMeasure.RESET;
                ItemUnitofMeasure.SETRANGE(ItemUnitofMeasure."Item No.", POSTransLine_l.Number);
                IF ItemUnitofMeasure.FIND('-') THEN
                    REPEAT
                        CountUnit += 1;
                    UNTIL (ItemUnitofMeasure.NEXT = 0);

                IF CountUnit > 1 THEN
                    POSTransLine_l."FSN QuantityScan" := POSTransLine_l.Quantity
                ELSE
                    POSTransLine_l."FSN QuantityScan" := POSTransLine_l."FSN QuantityScan" + 1;
                POSTransLine_l.MODIFY;

                IF POSTransLine_l."FSN QuantityScan" = POSTransLine_l.Quantity THEN BEGIN
                    POSTransLine_l."FSN Additional Action" := POSTransLine_l."FSN Additional Action"::Nothing;
                    POSTransLine_l.MODIFY;
                END;

                ExitOnly := TRUE;
                ItemNo := '';
                EXIT(FALSE);

            END ELSE BEGIN
                POSTransLine_l."FSN Additional Action" := POSTransLine_l."FSN Additional Action"::Nothing;
                POSTransLine_l.MODIFY;
                ExitOnly := TRUE;
                ItemNo := '';
                EXIT(FALSE);
            END;
        END ELSE BEGIN
            IF Description = '' THEN BEGIN
                ErrorText := COPYSTR(STRSUBSTNO(lText001, ItemNo2), 1, 250);
            END ELSE
                ErrorText := COPYSTR(STRSUBSTNO(lText001, Description), 1, 250);
            EXIT(FALSE);
        END;
        POSSession.SetValue('FirstPass', 'false');
        EXIT(TRUE);
    end;

    procedure ScannConfirm(var POSTransLine: Record "LSC POS Trans. Line"; ItemCode: Code[20]; Receipt: Code[20]; var OptionVal: Option Diferent,none; var UnitofMeasure: Code[10]): Boolean
    var
        Valunit: Boolean;
    begin
        Valunit := false;
        POSTransLine.RESET;
        POSTransLine.SETCURRENTKEY("Receipt No.", "Entry Type", Number, "Variant Code", "Unit of Measure", "Entry Status");
        POSTransLine.SETRANGE(POSTransLine."Receipt No.", Receipt);
        POSTransLine.SETRANGE(POSTransLine."Entry Type", POSTransLine."Entry Type"::Item);
        POSTransLine.SETRANGE(POSTransLine.Number, ItemCode);
        if UnitofMeasure <> '' then begin
            Valunit := true;
            POSTransLine.SetRange("Unit of Measure", UnitofMeasure);
        end;
        POSTransLine.SetRange(POSTransLine."Entry Status", POSTransLine."Entry Status"::" ");
        POSTransLine.SETRANGE(POSTransLine."FSN Additional Action", POSTransLine."FSN Additional Action"::ConfirmScann);
        IF POSTransLine.FindFirst THEN begin
            IF POSTransLine."FSN QuantityScan" <> POSTransLine.Quantity THEN begin
                OptionVal := OptionVal::Diferent;
                exit(true)
            end
            else begin
                OptionVal := OptionVal::none;
                exit(true);
            end;
        end else
            if Valunit then begin
                UnitofMeasure := '';
                POSTransLine.RESET;
                POSTransLine.SETCURRENTKEY("Receipt No.", "Entry Type", Number, "Variant Code", "Unit of Measure", "Entry Status");
                POSTransLine.SETRANGE(POSTransLine."Receipt No.", Receipt);
                POSTransLine.SETRANGE(POSTransLine."Entry Type", POSTransLine."Entry Type"::Item);
                POSTransLine.SETRANGE(POSTransLine.Number, ItemCode);
                POSTransLine.SETFILTER(POSTransLine."Entry Status", '<>%1', POSTransLine."Entry Status"::Voided);
                POSTransLine.SETRANGE(POSTransLine."FSN Additional Action", POSTransLine."FSN Additional Action"::ConfirmScann);
                IF POSTransLine.FindFirst THEN
                    IF POSTransLine."FSN QuantityScan" <> POSTransLine.Quantity THEN begin
                        OptionVal := OptionVal::Diferent;
                        exit(true)
                    end
                    else begin
                        OptionVal := OptionVal::none;
                        exit(true);
                    end;
            end else
                exit(false);
    end;

    // usa funcion ValidateItemPendingScann() para: leer "POS Trans. Line" filtrando "Additional Action"::ConfirmScann
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

    //muestra mensaje indicando como se efectuo la venta orignal
    procedure CheckTenderReturnSale(pTransaction: Record "LSC POS Transaction")
    var
        TenderTrans: Record "LSC Trans. Payment Entry";
        TendersText: Text;
        lText001: Label '%1 - $%2 \';
        TenderTypeSetup: Record "LSC Tender Type Setup";
        lText002: Label 'Tenders type not exists!';
        CashSums: Decimal;
        CashSumName: Text[50];
        IsToday: Boolean;
        TransactionHeader_l: Record "LSC Transaction Header";
        lText003: Label 'Cash + Check';
    begin
        IF NOT pTransaction."Sale Is Return Sale" THEN
            EXIT;

        IsToday := TRUE;
        IF TransactionHeader_l.GET(pTransaction."Retrieved from Store No.", pTransaction."Retrieved from POS Term. No.", pTransaction."Retrieved from Trans. No.") THEN
            IsToday := TransactionHeader_l.Date = TODAY;

        TendersText := '';
        CashSums := 0;
        CashSumName := '';
        TenderTrans.RESET;
        TenderTrans.SETCURRENTKEY("Store No.", "POS Terminal No.", "Transaction No.", "Line No.");
        TenderTrans.SETRANGE(TenderTrans."Store No.", pTransaction."Retrieved from Store No.");
        TenderTrans.SETRANGE(TenderTrans."POS Terminal No.", pTransaction."Retrieved from POS Term. No.");
        TenderTrans.SETRANGE(TenderTrans."Transaction No.", pTransaction."Retrieved from Trans. No.");
        IF TenderTrans.FINDSET() THEN
            REPEAT
                IF TenderTypeSetup.GET(TenderTrans."Tender Type") THEN
                    IF TenderTypeSetup."FSN Function in CC" = TenderTypeSetup."FSN Function in CC"::Check THEN BEGIN
                        IF IsToday THEN
                            TendersText += STRSUBSTNO(lText001, COPYSTR(TenderTypeSetup.Description, 1, 15), FORMAT(TenderTrans."Amount Tendered"))
                        ELSE BEGIN
                            CashSums += TenderTrans."Amount Tendered";
                            CashSumName := lText003;
                        END;
                    END ELSE
                        IF TenderTypeSetup."FSN Function in CC" = TenderTypeSetup."FSN Function in CC"::Change THEN BEGIN
                            CashSums += TenderTrans."Amount Tendered";
                            IF CashSumName = '' THEN
                                CashSumName := TenderTypeSetup.Description;
                        END ELSE
                            TendersText += STRSUBSTNO(lText001, COPYSTR(TenderTypeSetup.Description, 1, 15), FORMAT(TenderTrans."Amount Tendered"));
            UNTIL TenderTrans.NEXT = 0;

        IF CashSums <> 0 THEN
            TendersText += STRSUBSTNO(lText001, COPYSTR(CashSumName, 1, 15), FORMAT(CashSums));
        IF TendersText = '' THEN
            TendersText := lText002;
        POSGUI.PosMessage(TendersText);
    end;

    //Valida si se encuentran transaciones marcadas con Z
    procedure IsClosedTransExist(): Boolean
    var
        Trans: Record "LSC Transaction Header";
        RefDate: Date;
        Parameter: Record "FSN Parameter";
    begin
        RefDate := TODAY;
        Parameter.reset;
        Parameter.SetRange(Parameter.Grupo, 'ZREPORT');
        if Parameter.FindFirst() then begin
            if Parameter.Activo then begin
                Trans.RESET;
                Trans.SETCURRENTKEY("Store No.", Date);
                Trans.SETRANGE("Store No.", POSSession.StoreNo);
                Trans.SETRANGE("POS Terminal No.", POSSession.TerminalNo);
                Trans.SETRANGE("Transaction Type", Trans."Transaction Type"::Sales);
                Trans.SETRANGE(Date, RefDate);
                Trans.SETFILTER(Trans."Z-Report ID", '<>%1', '');
                IF Trans.FINDFIRST THEN BEGIN
                    EXIT(TRUE);
                END;
            end;
        end;
    end;

    procedure ValidateTenderTypeAmount(REC: Record "LSC POS Transaction"; TenderCode: Code[10]; CurrInput: Text; Step: Integer; pBalance: Decimal): Boolean;
    var
        TransPaymentEntry_l: Record "LSC Trans. Payment Entry";
        TransPaymentEntry2_l: Record "LSC Trans. Payment Entry";
        TransPaymentEntry3_l: Record "LSC Trans. Payment Entry";
        POSTransLine_l: Record "LSC POS Trans. Line";
        TenderTypeSetup: Record "LSC Tender Type Setup";
        TotalAmount: Decimal;
        TendersAmount: Decimal;
        lText001: Label 'Must be use tender CASH because date is old in Check';
        lText002: Label 'Tender type %1 not exists for this transaction';
        lText003: Label 'Payment in tender type %1 is complete';
        lText004: Label '%1 not exists. Value %2, %3';
        lText005: Label 'Amount is not correct';
        lText007: Label 'Limit for amount is %1';
        LimitAmount: Decimal;
        OkNext: Boolean;
        lCalcSums: Decimal;
        IsToday: Boolean;
        DelOrder: Record "LSC Delivery Order";
        lText008: Label 'Order delivery already cancel. Must be use POST CALLCENTER';
    begin
        TotalAmount := 0;
        IF CurrInput = '' THEN
            TotalAmount := pBalance
        ELSE
            EVALUATE(TotalAmount, CurrInput);

        IF NOT REC."Sale Is Return Sale" AND DelOrder.GET(REC."Receipt No.") AND
          (pBalance = 0) THEN BEGIN
            POSTransLine_l.RESET;
            POSTransLine_l.SETCURRENTKEY("Receipt No.", "Entry Type", Number, "Variant Code", "Unit of Measure", "Entry Status");
            POSTransLine_l.SETRANGE(POSTransLine_l."Receipt No.", REC."Receipt No.");
            POSTransLine_l.SETRANGE(POSTransLine_l."Entry Type", POSTransLine_l."Entry Type"::Payment);
            POSTransLine_l.SETRANGE(POSTransLine_l."Entry Status", 0);
            IF POSTransLine_l.FINDFIRST THEN
                ERROR(lText008);
        END;

        LimitAmount := 500000;
        IF TotalAmount > LimitAmount THEN
            ERROR(lText007, FORMAT(LimitAmount));

        IsToday := TRUE;
        IF REC."Sale Is Return Sale" THEN BEGIN
            IF NOT TenderTypeSetup.GET(TenderCode) THEN
                ERROR(STRSUBSTNO(lText004, TenderTypeSetup.TABLECAPTION, TenderCode, ''));

            TransPaymentEntry_l.RESET;
            TransPaymentEntry_l.SETCURRENTKEY("Store No.", "POS Terminal No.", "Transaction No.", "Line No.");
            TransPaymentEntry_l.SETRANGE(TransPaymentEntry_l."Store No.", REC."Retrieved from Store No.");
            TransPaymentEntry_l.SETRANGE(TransPaymentEntry_l."POS Terminal No.", REC."Retrieved from POS Term. No.");
            TransPaymentEntry_l.SETRANGE(TransPaymentEntry_l."Transaction No.", REC."Retrieved from Trans. No.");
            IF NOT TransPaymentEntry_l.FINDFIRST THEN
                ERROR(STRSUBSTNO(lText002, TenderTypeSetup.Description))
            ELSE
                IsToday := TransPaymentEntry_l.Date = TODAY;

            IF (TenderTypeSetup."FSN Function in CC" = TenderTypeSetup."FSN Function in CC"::Change) THEN BEGIN
                IF IsToday THEN
                    TransPaymentEntry_l.SETRANGE(TransPaymentEntry_l."Tender Type", TenderCode)
                ELSE
                    TransPaymentEntry_l.SETFILTER(TransPaymentEntry_l."Tender Type", '=%1|=%2', TenderCode, '2');
            END ELSE BEGIN
                TransPaymentEntry_l.SETRANGE(TransPaymentEntry_l."Tender Type", TenderCode);
            END;

            IF NOT TransPaymentEntry_l.FINDFIRST THEN
                ERROR(STRSUBSTNO(lText002, TenderTypeSetup.Description));

            OkNext := FALSE;
            REPEAT
                IF TransPaymentEntry_l."Amount Tendered" = TotalAmount THEN BEGIN
                    TransPaymentEntry2_l := TransPaymentEntry_l;
                    OkNext := TRUE;
                END;
            UNTIL (TransPaymentEntry_l.NEXT = 0) OR OkNext;

            lCalcSums := 0;
            IF NOT OkNext THEN BEGIN
                IF TenderTypeSetup."FSN Function in CC" = TenderTypeSetup."FSN Function in CC"::Change THEN BEGIN
                    TransPaymentEntry3_l.COPYFILTERS(TransPaymentEntry_l);
                    TransPaymentEntry3_l.CALCSUMS(TransPaymentEntry3_l."Amount Tendered");
                    lCalcSums += TransPaymentEntry3_l."Amount Tendered";

                    IF lCalcSums <> TotalAmount THEN
                        ERROR(STRSUBSTNO(lText005, TenderTypeSetup.Description));
                END ELSE
                    ERROR(STRSUBSTNO(lText005, TenderTypeSetup.Description));
            END;

            CASE TenderTypeSetup."FSN Function in CC" OF
                TenderTypeSetup."FSN Function in CC"::Check:
                    BEGIN
                        IF TransPaymentEntry2_l.Date <> TODAY THEN
                            ERROR(lText001);
                    END;
            END;
            TransPaymentEntry_l.CALCSUMS(TransPaymentEntry_l."Amount Tendered");
            TendersAmount := TransPaymentEntry_l."Amount Tendered";

            POSTransLine_l.RESET;
            POSTransLine_l.SETCURRENTKEY("Receipt No.", "Entry Type", Number, "Variant Code", "Unit of Measure", "Entry Status");
            POSTransLine_l.SETRANGE(POSTransLine_l."Receipt No.", REC."Receipt No.");
            POSTransLine_l.SETRANGE(POSTransLine_l."Entry Type", POSTransLine_l."Entry Type"::Payment);
            POSTransLine_l.SETRANGE(POSTransLine_l.Number, TenderCode);
            POSTransLine_l.SETFILTER(POSTransLine_l."Entry Status", '<>%1', POSTransLine_l."Entry Status"::Voided);
            POSTransLine_l.CALCSUMS(POSTransLine_l.Amount);
            IF (POSTransLine_l.Amount = 0) AND (TendersAmount = 0) THEN
                EXIT(TRUE);

            IF TendersAmount = POSTransLine_l.Amount THEN
                ERROR(STRSUBSTNO(lText003, TenderTypeSetup.Description));
        END;

        EXIT(TRUE);
    end;

    //valida cuando es devolucion Giftcard
    procedure ValidateSaleIsReturnSale(var ReturnPOSTransaction: Record "LSC POS Transaction"): Boolean
    var
        ReturnVoucherEntries: Record "LSC Voucher Entries";
        InitVoucherEntriesReturn: Record "LSC Voucher Entries";
        DataEntryReturn: Record "LSC POS Data Entry";
        TransPaymentLine_l: Record "LSC Trans. Payment Entry";
        ReturnTransInfocodeEntry: Record "LSC Trans. Infocode Entry";
        InitPOSTransInfocodeEntry: Record "LSC POS Trans. Infocode Entry";
        ExistVoucher: Boolean;
        Txt: Text;
        lText006: Label '\No. %1 , Monto: %2.';
        lText001: Label 'Se retornara el saldo a GIFTCARD %1';
    begin
        CLEAR(Txt);
        ReturnVoucherEntries.RESET;
        ReturnVoucherEntries.SETRANGE(ReturnVoucherEntries."Store No.", ReturnPOSTransaction."Store No.");
        ReturnVoucherEntries.SETRANGE(ReturnVoucherEntries."POS Terminal No.", ReturnPOSTransaction."POS Terminal No.");
        ReturnVoucherEntries.SETRANGE(ReturnVoucherEntries."Transaction No.", 0);
        ReturnVoucherEntries.SETRANGE(ReturnVoucherEntries."Receipt Number", ReturnPOSTransaction."Receipt No.");
        ReturnVoucherEntries.SETRANGE(ReturnVoucherEntries."Entry Type", ReturnVoucherEntries."Entry Type"::Redemption);
        ReturnVoucherEntries.SETRANGE(ReturnVoucherEntries.Voided, FALSE);
        IF ReturnVoucherEntries.FINDSET THEN BEGIN
            ExistVoucher := true;
            Txt += STRSUBSTNO(lText006, ReturnVoucherEntries."Voucher No.", FORMAT(-ReturnVoucherEntries.Amount));
            IF Txt <> '' THEN
                POSGUI.PosMessage(STRSUBSTNO(lText001, Txt));
        end else begin
            ReturnVoucherEntries.RESET;
            ReturnVoucherEntries.SETRANGE(ReturnVoucherEntries."Store No.", ReturnPOSTransaction."Store No.");
            ReturnVoucherEntries.SETRANGE(ReturnVoucherEntries."POS Terminal No.", ReturnPOSTransaction."Retrieved from POS Term. No.");
            ReturnVoucherEntries.SETRANGE(ReturnVoucherEntries."Transaction No.", ReturnPOSTransaction."Retrieved from Trans. No.");
            ReturnVoucherEntries.SETRANGE(ReturnVoucherEntries."Receipt Number", ReturnPOSTransaction."Retrieved from Receipt No.");
            ReturnVoucherEntries.SETRANGE(ReturnVoucherEntries."Entry Type", ReturnVoucherEntries."Entry Type"::Redemption);
            ReturnVoucherEntries.SETRANGE(ReturnVoucherEntries.Voided, FALSE);
            IF ReturnVoucherEntries.FINDSET THEN BEGIN
                REPEAT

                    InitVoucherEntriesReturn.INIT;
                    //InitVoucherEntriesReturn."Transaction No." := 0;
                    InitVoucherEntriesReturn."Voucher No." := ReturnVoucherEntries."Voucher No.";
                    InitVoucherEntriesReturn."Store No." := ReturnPOSTransaction."Store No.";
                    InitVoucherEntriesReturn."POS Terminal No." := ReturnPOSTransaction."POS Terminal No.";
                    InitVoucherEntriesReturn."Line No." := ReturnVoucherEntries."Line No.";
                    InitVoucherEntriesReturn."Receipt Number" := ReturnPOSTransaction."Receipt No.";
                    InitVoucherEntriesReturn."Entry Type" := ReturnVoucherEntries."Entry Type";
                    InitVoucherEntriesReturn."Voucher Type" := ReturnVoucherEntries."Voucher Type";
                    InitVoucherEntriesReturn.Date := ReturnPOSTransaction."Trans. Date";
                    InitVoucherEntriesReturn.Time := ReturnPOSTransaction."Trans Time";
                    InitVoucherEntriesReturn.Amount := -ReturnVoucherEntries.Amount;
                    InitVoucherEntriesReturn.Unposted := true;
                    InitVoucherEntriesReturn."Remaining Amount Now" := 0;
                    InitVoucherEntriesReturn."Write Off Amount" := 0;
                    InitVoucherEntriesReturn."One Time Redemption" := True;
                    InitVoucherEntriesReturn.Voided := false;
                    InitVoucherEntriesReturn.Insert(true);

                    Txt += STRSUBSTNO(lText006, ReturnVoucherEntries."Voucher No.", FORMAT(-ReturnVoucherEntries.Amount));
                    ExistVoucher := false;
                UNTIL ReturnVoucherEntries.NEXT = 0;

                IF Txt <> '' THEN
                    POSGUI.PosMessage(STRSUBSTNO(lText001, Txt));
            end else
                EXIT(TRUE);
        end;

        if not ExistVoucher then begin
            ReturnTransInfocodeEntry.RESET;
            ReturnTransInfocodeEntry.SETRANGE(ReturnTransInfocodeEntry."Store No.", ReturnPOSTransaction."Store No.");
            ReturnTransInfocodeEntry.SETRANGE(ReturnTransInfocodeEntry."POS Terminal No.", ReturnPOSTransaction."Retrieved from POS Term. No.");
            ReturnTransInfocodeEntry.SETRANGE(ReturnTransInfocodeEntry."Transaction No.", ReturnPOSTransaction."Retrieved from Trans. No.");
            ReturnTransInfocodeEntry.SETFILTER(ReturnTransInfocodeEntry."Type of Input", '%1|%2',
                ReturnTransInfocodeEntry."Type of Input"::"Apply To Entry", ReturnTransInfocodeEntry."Type of Input"::"Create Data Entry");
            ReturnTransInfocodeEntry.SETFILTER(ReturnTransInfocodeEntry."Transaction Type", '=%1|=%2',
                ReturnTransInfocodeEntry."Transaction Type"::Header, ReturnTransInfocodeEntry."Transaction Type"::"Payment Entry");
            IF ReturnTransInfocodeEntry.FINDSET THEN
                REPEAT
                    InitPOSTransInfocodeEntry.INIT;
                    InitPOSTransInfocodeEntry."Receipt No." := ReturnPOSTransaction."Receipt No.";
                    InitPOSTransInfocodeEntry."Transaction Type" := ReturnTransInfocodeEntry."Transaction Type";
                    InitPOSTransInfocodeEntry."Line No." := ReturnTransInfocodeEntry."Line No.";
                    InitPOSTransInfocodeEntry.Infocode := ReturnTransInfocodeEntry.Infocode;
                    InitPOSTransInfocodeEntry."Store No." := ReturnPOSTransaction."Store No.";
                    InitPOSTransInfocodeEntry.Information := ReturnTransInfocodeEntry.Information;
                    InitPOSTransInfocodeEntry.Date := ReturnPOSTransaction."Trans. Date";
                    InitPOSTransInfocodeEntry.Time := ReturnPOSTransaction."Trans Time";
                    InitPOSTransInfocodeEntry."POS Terminal No." := ReturnPOSTransaction."POS Terminal No.";
                    InitPOSTransInfocodeEntry."Staff ID" := ReturnPOSTransaction."Staff ID";
                    InitPOSTransInfocodeEntry."Type of Input" := InitPOSTransInfocodeEntry."Type of Input"::"Apply To Entry";
                    InitPOSTransInfocodeEntry."Selected Quantity" := 1;
                    InitPOSTransInfocodeEntry.Counter := 1;
                    InitPOSTransInfocodeEntry.Amount := -ReturnTransInfocodeEntry.Amount;
                    IF NOT InitPOSTransInfocodeEntry.INSERT THEN
                        InitPOSTransInfocodeEntry.MODIFY;
                UNTIL ReturnTransInfocodeEntry.NEXT = 0;
            EXIT(TRUE);
        end;
    end;

    //Envia voucher entrie al HO cuando es devolucion
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Post Utility", 'OnAfterPostTransactionFiscalProcess', '', true, true)]
    local procedure "LSC POS Post Utility_OnAfterPostTransactionFiscalProcess"
    (
        var TransactionHeader: Record "LSC Transaction Header";
        var FiscalProcessActive: Boolean;
        var FiscalProcessOk: Boolean;
        var POSTransaction: Record "LSC POS Transaction"
    )
    var
        VoucherEntries: Record "LSC Voucher Entries";
        VoucherEntriesTemp: Record "LSC Voucher Entries" temporary;
        PosFuncProfile: Record "LSC POS Func. Profile";
        SendVoucherEntryUtils: Codeunit LSCSendVoucherEntryUtils;
        ResponseCode: Code[30];
        lTransPaymentEntry: Record "LSC Trans. Payment Entry";

    begin
        lTransPaymentEntry.RESET;
        lTransPaymentEntry.SETCURRENTKEY("Store No.", "POS Terminal No.", "Transaction No.", "Line No.");
        lTransPaymentEntry.SETRANGE(lTransPaymentEntry."Store No.", TransactionHeader."Store No.");
        lTransPaymentEntry.SETRANGE(lTransPaymentEntry."POS Terminal No.", TransactionHeader."POS Terminal No.");
        lTransPaymentEntry.SETRANGE(lTransPaymentEntry."Transaction No.", TransactionHeader."Transaction No.");
        lTransPaymentEntry.SETRANGE(lTransPaymentEntry."Change Line", TRUE);
        IF lTransPaymentEntry.FINDLAST THEN BEGIN
            POSSession.SetValue('PaymentChange', StrSubstNo('Cambio: %1', FORMAT(ROUND(lTransPaymentEntry."Amount Tendered", 0.01))));
            POSTransC.LookUp(true, 'CHANGE', '');
        END;

        VoucherEntriesTemp.DeleteAll();
        VoucherEntries.Reset;
        VoucherEntries.SetRange("Store No.", TransactionHeader."Store No.");
        VoucherEntries.SetRange("POS Terminal No.", TransactionHeader."POS Terminal No.");
        VoucherEntries.SetRange("Receipt Number", TransactionHeader."Receipt No.");
        if VoucherEntries.FindFirst then begin
            if TransactionHeader."Sale Is Return Sale" then begin
                VoucherEntriesTemp.Init;
                VoucherEntriesTemp := VoucherEntries;
                VoucherEntriesTemp.Insert;
                PosFuncProfile.Get(POSSession.FunctionalityProfileID);
                SendVoucherEntryUtils.SetPosFunctionalityProfile(PosFuncProfile."Profile ID");
                SendVoucherEntryUtils.SendRequest(ResponseCode, ErrorText, false, false, VoucherEntriesTemp);
                SendVoucherEntryUtils.SetCommunicationError(ResponseCode, ErrorText);
            end;
        end;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Infocode Utility", 'OnBeforeInfocodeRequired', '', true, true)]
    local procedure "LSC POS Infocode Utility_OnBeforeInfocodeRequired"
    (
        Module: Code[10];
        Code: Code[20];
        Code2: Code[20];
        var Handled: Boolean;
        var ReturnValue: Boolean
    )
    var
        GiftParameter: Record "FSN Parameter";
        TableSpeInfocode: Record "LSC Table Specific Infocode";
        Infocode: Record "LSC Infocode";
        ErrorText: Text;
        XMLRequest: Text;
        XMLResponse: Text;
        RequestID: Text[50];
        PosMenuLineTemp: Record "LSC POS Menu Line" temporary;
        Processed: Boolean;
        MsgResult: text;
        FSNUtility: Codeunit "FSN Utility";
    begin

        if not Handled then begin
            GiftParameter.Reset();
            GiftParameter.SetRange(GiftParameter.Grupo, 'INFOCODE');
            GiftParameter.SetRange(GiftParameter.Codigo, Module);
            GiftParameter.SetRange(GiftParameter.Valor, Code);
            if GiftParameter.FindSet() then begin
                Handled := ReturnVoucher;
            end;
        end;
        //PROCESS GIFTCAR CC
        if not Handled then//140725
            if Module = 'ITEM' THEN BEGIN
                RequestID := 'FSNCC';
                Processed := false;
                FSNUtility.InvokeGlobalChannel(XMLRequest, XMLResponse, RequestID, PosMenuLineTemp, Processed, MsgResult);
                if Processed then begin
                    TableSpeInfocode.SetCurrentKey("Table ID", Value, "Infocode Code");
                    TableSpeInfocode.SetRange("Table ID", Database::Item);
                    TableSpeInfocode.SetRange(Value, Code);
                    if TableSpeInfocode.FindFirst() then
                        if Infocode.Get(TableSpeInfocode."Infocode Code") and (Infocode.Type = Infocode.Type::"Create Data Entry") then
                            Handled := true;
                end;
            end;
    end;

    local procedure DeleteLinevoided(POSTransaction: Record "LSC POS Transaction"): Boolean
    var
        PosTransLine: Record "LSC POS Trans. Line";
        PosTransVoid: Record "LSC POS Voided Trans. Line";
        Resp: Boolean;
        POSTransPerDisc: Record "LSC POS Trans. Per. Disc. Type";
        PosFunc: Codeunit "LSC POS Functions";
    begin
        POSTransPerDisc.Reset;
        POSTransPerDisc.SetCurrentKey(DiscType);
        POSTransPerDisc.SetRange(DiscType, POSTransPerDisc.DiscType::Customer);
        POSTransPerDisc.SetRange("Receipt No.", POSTransaction."Receipt No.");
        PosFunc.PosTransDiscSetTableFilter(1, POSTransPerDisc);
        if PosFunc.PosTransDiscFindRec(1, '-', POSTransPerDisc) then begin
            repeat
                if PosTransLine.Get(POSTransPerDisc."Receipt No.", POSTransPerDisc."Line No.") then
                    if (PosTransLine."Entry Status" = PosTransLine."Entry Status"::Voided) and (PosTransLine."Entry Type" = PosTransLine."Entry Type"::Item) then begin
                        Resp := true;
                        PosTransVoid.TransferFields(PosTransLine);
                        if not PosTransVoid.Insert(true) then
                            PosTransVoid.Modify(true);
                        PosTransLine.Delete(true);
                        PosFunc.PosTransDiscDeleteRec(POSTransPerDisc);
                    end;
            until PosFunc.PosTransDiscNextRec(1, 1, POSTransPerDisc) = 0;
        end;

        PosTransLine.Reset();
        PosTransLine.SetRange("Receipt No.", POSTransaction."Receipt No.");
        PosTransLine.SetRange("Entry Status", PosTransLine."Entry Status"::Voided);
        PosTransLine.SetRange("Entry Type", PosTransLine."Entry Type"::Item);
        if PosTransLine.FindSet() then begin
            repeat
                Resp := true;
                PosTransVoid.TransferFields(PosTransLine);
                if not PosTransVoid.Insert(true) then
                    PosTransVoid.Modify(true);
                PosTransLine.Delete(true);
            until PosTransLine.Next() = 0;
        end;
        exit(Resp);
    end;

    procedure ReturnVoucher(): Boolean
    var
        VouchPosTransaction: Record "LSC POS Transaction";
        VoucherEntries: Record "LSC Voucher Entries";
    begin
        if VouchPosTransaction.Get(POSTransC.GetReceiptNo()) then begin
            if VouchPosTransaction."Sale Is Return Sale" then begin
                VoucherEntries.Reset;
                VoucherEntries.SetRange("Store No.", VouchPosTransaction."Store No.");
                VoucherEntries.SetRange("POS Terminal No.", VouchPosTransaction."POS Terminal No.");
                VoucherEntries.SetRange("Receipt Number", VouchPosTransaction."Receipt No.");
                if VoucherEntries.FindFirst then
                    exit(true);
            end;
            exit(false);
        end;
    end;


    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Transaction Events", 'OnAfterVoidPressed', '', true, true)]
    local procedure "LSC POS Transaction Events_OnAfterVoidPressed"(var POSTransaction: Record "LSC POS Transaction")
    var
        VoucherEntries: Record "LSC Voucher Entries";
    begin
        VoucherEntries.Reset;
        VoucherEntries.SetRange("Store No.", POSTransaction."Store No.");
        VoucherEntries.SetRange("POS Terminal No.", POSTransaction."POS Terminal No.");
        VoucherEntries.SetRange("Receipt Number", POSTransaction."Receipt No.");
        if VoucherEntries.FindFirst then begin
            if POSTransaction."Sale Is Return Sale" then begin
                VoucherEntries.Voided := true;
                VoucherEntries.Modify(true);
            end;
        end;
    end;
    #endregion
    #region [subcriptions]

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Transaction Events", 'OnAfterTenderKeyPressedEx', '', true, true)]
    local procedure "LSC POS Transaction Events_OnAfterTenderKeyPressedEx"
    (
        var POSTransaction: Record "LSC POS Transaction";
        var POSTransLine: Record "LSC POS Trans. Line";
        var CurrInput: Text;
        var TenderTypeCode: Code[10];
        var TenderAmountText: Text;
        var IsHandled: Boolean
    )
    var
        POSTranCod: Codeunit "LSC POS Transaction";
        POSTransLinecode: Codeunit "LSC POS Trans. Lines";
        FSNOfferExtend: Record "FSN Fasani Offer Extend";
        CustomerCred: Record Customer;
        Cust: Record Customer;
        RestricOption: Option Normal,NameOnly,ExcpName,All;
        RestricOption_1: Option Normal,NameOnly,ExcpName,All;
        ValidateTender: Boolean;
        DeleteCoupon: Boolean;
        ValidateCreditCustomer: Boolean;
        Step: Integer;
        CreditAmount: Decimal;
        Val: Text[100];
        ErrorText: Text;
        pCurrInput: Text;
        menuLine: Record "LSC POS Menu Line";
        posTransCode: Codeunit "LSC POS Transaction";
    begin

        if ValidatePaintmenCat(POSTransaction) and (TenderTypeCode <> '1') then begin
            IsHandled := TRUE;
            POSGUI.PosMessage('La venta contiene productos que solo puede ser registrados en efectivo.');
            exit;
        end;

        //Vallida credito del cliente
        if not POSTransaction."Sale Is Return Sale" then begin
            IF TenderTypeCode = '4' THEN begin
                CustomerCred.reset;
                CustomerCred.get(POSTransaction."Customer No.");
                ValidateCreditCustomer := TRUE;
                ValidateCreditCustomer := ValidateCustomer(CustomerCred, false, false, POSTranCod.GetOutstandingBalance(), ErrorText, true);
                if not ValidateCreditCustomer then begin
                    POSGUI.PosMessage(ErrorText);
                    IsHandled := TRUE;
                end;
            end;
        end;

        //ERROR VIP
        POSSession.SetValue('#TENDERTEMP', TenderTypeCode);

        //no duplicar cupones
        FSNOfferExtend.RESET; //dgarzona 8-2022-
        FSNOfferExtend.SETCURRENTKEY("Record Type", "Tender Type", "Type Extention");
        FSNOfferExtend.SETRANGE("Record Type", FSNOfferExtend."Record Type"::Coupon);
        FSNOfferExtend.SETRANGE("Tender Type", TenderTypeCode);
        FSNOfferExtend.SETRANGE("Type Extention", FSNOfferExtend."Type Extention"::"Add Automatic");
        IF FSNOfferExtend.FIND('-') THEN BEGIN
            POSTransLine.RESET;
            POSTransLine.SETCURRENTKEY("Receipt No.", "Entry Type", "Entry Status", "Coupon Code");
            POSTransLine.SETRANGE("Entry Type", 6);
            POSTransLine.SETRANGE("Receipt No.", POSTransaction."Receipt No.");
            POSTransLine.SETRANGE("Coupon Code", FSNOfferExtend."No.");
            POSTransLine.SETRANGE("Entry Status", POSTransLine."Entry Status"::" ");
            IF NOT POSTransLine.FIND('-') THEN
                REPEAT
                    IF FSNOfferExtend.Status = FSNOfferExtend.Status::Enabled THEN BEGIN
                        pCurrInput := FORMAT(FSNOfferExtend."No.");
                        POSTranCod.SetCurrInput(pCurrInput);
                        POSTranCod.CouponPressed;
                        POSTranCod.SetPOSState('PAYMENT');
                    END;
                UNTIL FSNOfferExtend.NEXT = 0;
        END;

        //eliminar cupon de cambio de oferta descuento
        POSTransLine.Reset();
        POSTransLine.SetCurrentKey("Receipt No.", "Entry Type", "Entry Status");
        POSTransLine.SetRange("Entry Type", 6);
        POSTransLine.SetRange("Receipt No.", POSTransaction."Receipt No.");
        POSTransLine.SetRange("Entry Status", POSTransLine."Entry Status"::" ");
        if POSTransLine.Find('-') then
            repeat
                DeleteCoupon := true;
                FSNOfferExtend.Reset();
                FSNOfferExtend.SetCurrentKey("No.");
                FSNOfferExtend.SetRange("No.", POSTransLine."Coupon Code");
                if not FSNOfferExtend.Find('-') then
                    DeleteCoupon := false
                else
                    repeat
                        if TenderTypeCode = FSNOfferExtend."Tender Type" then begin
                            DeleteCoupon := false;
                        end;
                    until FSNOfferExtend.next = 0;

                if DeleteCoupon then begin
                    POSTransLinecode.SetCurrentLine(POSTransLine);
                    POSTranCod.VoidLinePressed();
                end else begin
                    CalcPrec(POSTransLine);
                end;

            until POSTransLine.next = 0; //dgarzona 8-2022+
    end;

    procedure ValidateCouponVipTenderTyp5(POSTransaction: Record "LSC POS Transaction")
    var
        POSTransLine: Record "LSC POS Trans. Line";
        FSNOfferExtend: Record "FSN Fasani Offer Extend";
        FSNParameter: Record "FSN Parameter";
    begin

        if FSNParameter.Get('POS', 'VALPAYMENT') and FSNParameter.Activo then begin
            POSTransLine.RESET;
            POSTransLine.SETCURRENTKEY("Receipt No.", "Entry Type", "Entry Status", "Coupon Code");
            POSTransLine.SETRANGE("Receipt No.", POSTransaction."Receipt No.");
            POSTransLine.SETRANGE("Entry Type", 6);
            POSTransLine.SETRANGE("Entry Status", POSTransLine."Entry Status"::" ");
            POSTransLine.SETRANGE("Coupon Code", 'VIPAGRI');
            IF POSTransLine.FIND('-') THEN
                REPEAT
                    FSNOfferExtend.RESET;
                    FSNOfferExtend.SETCURRENTKEY("Record Type", "Tender Type", "Type Extention");
                    FSNOfferExtend.SETRANGE("Record Type", FSNOfferExtend."Record Type"::Coupon);
                    FSNOfferExtend.SETRANGE(FSNOfferExtend."No.", POSTransLine."Coupon Code");
                    FSNOfferExtend.SETRANGE("Type Extention", FSNOfferExtend."Type Extention"::"Add Automatic");
                    IF FSNOfferExtend.FindFirst() THEN BEGIN
                        if FSNOfferExtend."Tender Type" = '5' then begin
                            if not ValidateTenderType5(POSTransaction, FSNOfferExtend."Tender Type") then
                                POSTransLine.VoidLine();
                        end;
                    end;
                until POSTransLine.next = 0;
        end;
    end;

    procedure ValidateTenderType5(POSTransaction: Record "LSC POS Transaction"; TenderType: Code[10]): boolean
    var
        POSTransLine: Record "LSC POS Trans. Line";
    begin
        POSTransLine.RESET;
        POSTransLine.SETRANGE("Receipt No.", POSTransaction."Receipt No.");
        POSTransLine.SETRANGE(POSTransLine."Entry Type", POSTransLine."Entry Type"::payment);
        POSTransLine.SETRANGE(POSTransLine."Number", TenderType);
        POSTransLine.SETRANGE("Entry Status", POSTransLine."Entry Status"::" ");
        if POSTransLine.FindFirst() then
            exit(true)
        else
            exit(false);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Transaction Events", 'OnAfterRetSuspended', '', true, true)]
    local procedure "LSC POS Transaction Events_OnAfterRetSuspended"
    (
        var POSTransaction: Record "LSC POS Transaction";
        var POSTransLine: Record "LSC POS Trans. Line";
        var CurrInput: Text
    )
    begin
        ValidateCouponVipTenderTyp5(POSTransaction);
    end;

    local procedure ValidatePaintmenCat(PosTransacc: Record "LSC POS Transaction"): Boolean
    var
        myInt: Integer;
        POSTransLine: Record "LSC POS Trans. Line";
        Item: Record Item;
    begin
        POSTransLine.Reset();
        POSTransLine.SetRange("Receipt No.", PosTransacc."Receipt No.");
        POSTransLine.SetRange("Entry Type", POSTransLine."Entry Type"::Item);
        POSTransLine.SetRange("Entry Status", POSTransLine."Entry Status"::" ");
        if POSTransLine.FindFirst() then
            repeat
                if Item.GET(POSTransLine.Number) then
                    if Item."Item Category Code" = '05002' then
                        exit(true);
            until POSTransLine.Next() = 0;
    end;

    local procedure CalcPrec(POSTransLine: Record "LSC POS Trans. Line")
    var
        PosTrans: Record "LSC POS Trans. Line";
    begin
        if POSTransLine."Coupon Barcode No." = 'VIPAGRI' then begin
            PosTrans.Reset();
            PosTrans.SetCurrentKey("Receipt No.", "Entry Type", "Entry Status");
            PosTrans.SetRange("Receipt No.", POSTransLine."Receipt No.");
            PosTrans.SetRange("Entry Type", POSTransLine."Entry Type"::Item);
            PosTrans.SetRange("Entry Status", PosTrans."Entry Status"::" ");
            if PosTrans.Find('-') then
                repeat
                    PosTrans.CalcPrices();
                    PosTrans.Modify(true);
                until PosTrans.Next() = 0;
        end;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Transaction Events", 'OnAfterValidateCustomerTender', '', true, true)]
    local procedure "LSC POS Transaction Events_OnAfterValidateCustomerTender"
    (
        var POSTransaction: Record "LSC POS Transaction";
        var POSTransLine: Record "LSC POS Trans. Line";
        var CurrInput: Text;
        var CustomerOrCardNo: Code[20]
    )
    VAR
        OptionInput: Option Customer,MembershipCard;
    begin
        ValidateChangeCustomerORMember(POSTransaction, CurrInput, OptionInput);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Controller", 'OnBeforeRunPos', '', true, true)]
    local procedure "LSC POS Controller_OnBeforeRunPos"
    (
        StaffID: Code[20];
        PosTerminal: Code[10];
        var Handled: Boolean
    )
    var
        lText001: Label 'Las transacciones han sido cerradas para este dia. ';
    begin
        POSSession.SetValue('FirstPass', 'true');
        Handled := IsClosedTransExist;
        if Handled then
            POSGUI.PosMessage(lText001);
    end;

    procedure ValidateType(postransaction: Record "LSC POS Transaction"): Boolean;
    var
        POSTransLine: Record "LSC POS Trans. Line";
        Cambio: Boolean;
        VATS: Record "VAT Posting Setup";
    begin
        POSTransLine.Reset();
        POSTransLine.SetRange("Receipt No.", postransaction."Receipt No.");
        POSTransLine.SetRange("Entry Status", POSTransLine."Entry Status"::" ");
        POSTransLine.SetRange("Entry Type", POSTransLine."Entry Type"::Item);
        POSTransLine.SetRange("VAT Calculation Type", POSTransLine."VAT Calculation Type"::"Sales Tax");
        if POSTransLine.Find('-') then begin
            repeat
                if POSTransLine."VAT Calculation Type" = POSTransLine."VAT Calculation Type"::"Sales Tax" then begin
                    POSTransLine."VAT Calculation Type" := POSTransLine."VAT Calculation Type"::"Normal VAT";
                    if VATS.GET(POSTransLine."VAT Bus. Posting Group", POSTransLine."VAT Prod. Posting Group") then;
                    POSTransLine.Validate("VAT Bus. Posting Group", VATS."VAT Bus. Posting Group");
                    POSTransLine.UpdateAmounts();
                    POSTransLine.CalcPrices();
                    POSTransLine.Modify(true);
                end;
            until POSTransLine.Next() = 0;
            exit(true);
        end;
    end;

    procedure ValidateCredictCustomer(PosTransaction: Record "LSC POS Transaction"): Boolean;
    var
        PosTransLine: Record "LSC POS Trans. Line";
    begin
        PosTransLine.Reset();
        PosTransLine.SetRange("Receipt No.", PosTransaction."Receipt No.");
        PosTransLine.SetRange("Entry Status", PosTransLine."Entry Status"::" ");
        PosTransLine.SetRange("Entry Type", PosTransLine."Entry Type"::Payment);
        PosTransLine.SetRange(Number, '4');
        if PosTransLine.FindFirst() then begin
            if PosTransLine."Card/Customer/Coup.Item No" <> PosTransaction."Customer No." then begin
                Message('EL CLIENTE NO ES EL MISMO EN LA TRANSACCION AL CREDITO');
                exit(true);
            end;
        end;
    end;

    //Validacion de transacciones ya registradas
    local procedure ValidateRegTransaction(TotalPOSTransaction: Record "LSC POS Transaction"): Boolean;
    var
        TransactionHeader_l: Record "LSC Transaction Header";
        lText010: Label 'Ya existe una transacción valida con recibo %1, Anule y haga nueva transacción';
    begin
        TransactionHeader_l.RESET;
        TransactionHeader_l.SETCURRENTKEY("Store No.", "Wrong Shift", "POS Terminal No.", "Receipt No.", "Entry Status");
        TransactionHeader_l.SETRANGE(TransactionHeader_l."Receipt No.", TotalPOSTransaction."Receipt No.");
        IF TransactionHeader_l.FINDFIRST THEN BEGIN
            EXIT(true);
        END;
    end;

    local procedure ValidateControl(GlobalPosTransaction: Record "LSC POS Transaction"): Boolean
    var
        myInt: Integer;
        Item: Record Item;
        PosTransLine: Record "LSC POS Trans. Line";
    begin
        PosTransLine.Reset();
        PosTransLine.SetRange("Receipt No.", GlobalPosTransaction."Receipt No.");
        PosTransLine.SetRange("Entry Status", PosTransLine."Entry Status"::" ");
        PosTransLine.SetRange("Entry Type", PosTransLine."Entry Type"::Item);
        if PosTransLine.Find('-') then
            repeat
                Item.Reset();
                if Item.Get(PosTransLine.Number) then
                    if (StrPos(Item."LSC Attrib 2 Code", 'CONTROL') > 0) then
                        if not RecetaReg(GlobalPosTransaction) then
                            if GetRecetas(ValidateRegisterR(GlobalPosTransaction), GlobalPosTransaction) then
                                exit(true);
            until PosTransLine.Next() = 0;
    end;

    local procedure ValidateRegisterR(GlobalPosTransaction: Record "LSC POS Transaction"): Text;
    var
        myInt: Integer;
        PostrasLine: Record "LSC POS Trans. Line";
    begin
        PostrasLine.Reset();
        PostrasLine.SetRange("Receipt No.", GlobalPosTransaction."Receipt No.");
        PostrasLine.SetRange("Entry Status", PostrasLine."Entry Status"::" ");
        PostrasLine.SetFilter("FSN Remission No.", '<>%1', '');
        if PostrasLine.FindFirst() then begin
            exit(PostrasLine."FSN Remission No.");
        end else
            exit(GlobalPosTransaction."Receipt No.");
    end;

    local procedure GetRecetas(Recibo: code[20]; POSTransacc: Record "LSC POS Transaction"): Boolean
    var
        query, con, Registro : Text;
        sqlConnection: DotNet SqlConnection;
        sqlCommand: DotNet SqlCommand;
        sqlDataReader: DotNet SqlDataReader;
        distrLocation: Record "LSC Distribution Location";
        ReailUser: Record "LSC Retail Setup";
        lTextConn: Label 'Data Source=%1;Initial Catalog=%2;Integrated Security=false; User ID=%3;Password=%4;';
        Exis: Boolean;
    begin
        IF GlobalParametro then begin
            ReailUser.Get();
            query := 'EXEC sp_obtenerDatosRecetas ''' + Recibo + '''';
            if distrLocation.Get(ReailUser."Local Store No.") then;
            con := StrSubstNo(lTextConn, distrLocation."DB Server Name", 'Prefactura', distrLocation."User ID", distrLocation.Password);
            sqlConnection := sqlConnection.SqlConnection(con);

            sqlConnection.Open();
            sqlCommand := sqlConnection.CreateCommand();
            sqlCommand.CommandText := query;
            SqlDataReader := sqlCommand.ExecuteReader();
            if SqlDataReader.Read() then begin
                Registro := Format(SqlDataReader.GetInt32(0));
                addLine(POSTransacc, Registro);
                sqlConnection.Close();
                exit(false);
            end else
                exit(true);
        end;
    end;

    local procedure GetReceta(Recibo: code[20]): Boolean
    var
        query, con : Text;
        sqlConnection: DotNet SqlConnection;
        sqlCommand: DotNet SqlCommand;
        sqlDataReader: DotNet SqlDataReader;
        distrLocation: Record "LSC Distribution Location";
        ReailUser: Record "LSC Retail Setup";
        lTextConn: Label 'Data Source=%1;Initial Catalog=%2;Integrated Security=false; User ID=%3;Password=%4;';
        Exis: Boolean;
        RegistroNo: Code[20];
        Registro: Text;
        Recipe_Name: Text;
    begin
        IF GlobalParametro then begin
            ReailUser.Get();
            query := 'EXEC sp_obtenerDatosRecetas ''' + Recibo + '''';
            if distrLocation.Get(ReailUser."Local Store No.") then;
            con := StrSubstNo(lTextConn, distrLocation."DB Server Name", 'Prefactura', distrLocation."User ID", distrLocation.Password);
            sqlConnection := sqlConnection.SqlConnection(con);

            sqlConnection.Open();
            sqlCommand := sqlConnection.CreateCommand();
            sqlCommand.CommandText := query;
            SqlDataReader := sqlCommand.ExecuteReader();
            if SqlDataReader.Read() then begin
                Registro := Format(SqlDataReader.GetInt32(0));
                Evaluate(Junta, SqlDataReader.GetString(2)); // Actualiza si es diferente
                RegistroNo := SqlDataReader.GetString(3);
                Recipe_Name := SqlDataReader.GetString(7);
                sqlConnection.Close();
                if DeleteRecetas(Registro, Format(Junta), RegistroNo, Recipe_Name) then;
            end;
        end;
    end;

    local procedure DeleteRecetas(Registro: Code[20]; JuntaT: Text; RegistroNo: Text; Recipe_Name: Text): Boolean
    var
        query, con : Text;
        sqlConnection: DotNet SqlConnection;
        sqlCommand: DotNet SqlCommand;
        sqlDataReader: DotNet SqlDataReader;
        distrLocation: Record "LSC Distribution Location";
        ReailUser: Record "LSC Retail Setup";
        lTextConn: Label 'Data Source=%1;Initial Catalog=%2;Integrated Security=false; User ID=%3;Password=%4;';
        Exis: Boolean;
    begin
        IF GlobalParametro then begin
            ReailUser.Get();
            query := 'EXEC sp_deleteRecipe ''' + Registro + ''',''' + JuntaT + ''',''' + RegistroNo + ''',''' + Recipe_Name + '''';
            if distrLocation.Get(ReailUser."Local Store No.") then;
            con := StrSubstNo(lTextConn, distrLocation."DB Server Name", 'Prefactura', distrLocation."User ID", distrLocation.Password);
            sqlConnection := sqlConnection.SqlConnection(con);

            sqlConnection.Open();
            sqlCommand := sqlConnection.CreateCommand();
            sqlCommand.CommandText := query;
            SqlDataReader := sqlCommand.ExecuteReader();
            if SqlDataReader.Read() then
                sqlConnection.Close();
        end;
    end;

    local procedure GlobalParametro(): Boolean
    var
        myInt: Integer;
    begin
        Parametrosfsn.Reset();
        Parametrosfsn.SetRange(Grupo, 'ADJUNT');
        Parametrosfsn.SetRange(Codigo, 'RECETA');
        IF Parametrosfsn.FindFirst() then
            exit(Parametrosfsn.Activo);
    end;

    local procedure RecetaReg(GlobalPosTransaction: Record "LSC POS Transaction"): Boolean
    var
        myInt: Integer;
        transLine: Record "LSC POS Trans. Line";
    begin
        transLine.Reset();
        transLine.SetRange("Receipt No.", GlobalPosTransaction."Receipt No.");
        transLine.SetRange("POS Terminal No.", GlobalPosTransaction."POS Terminal No.");
        transLine.SetRange("Entry Type", transLine."Entry Type"::FreeText);
        transLine.SetFilter(Description, '*Receta registrada con ID:*');
        exit(transLine.FindFirst());
    end;

    procedure addLine(
            transaction: Record "LSC POS Transaction";
            description: Text)
    var
        transLine: Record "LSC POS Trans. Line";
    begin
        transLine.Init();
        transLine.Validate("Receipt No.", transaction."Receipt No.");
        transLine.Validate("Store No.", transaction."Store No.");
        transLine.Validate("POS Terminal No.", transaction."POS Terminal No.");
        transLine.Validate("Line No.", getLine(transaction, 'new'));
        transLine.Validate("Entry Type", transLine."Entry Type"::FreeText);
        transLine.Validate("Description", 'Receta registrada con ID:  ' + description);
        transLine.Insert(true);
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

    local procedure ValidateDocumentType(LSCPosTransaction: Record "LSC POS Transaction"): Boolean
    var
        myInt: Integer;
        PosTransLine: Record "LSC POS Trans. Line";
        POSTransaction: Record "LSC POS Transaction";
        nos: Record "No. Series Line";
        Terminal: Record "LSC POS Terminal";
        NoSeriesMgt: Codeunit NoSeriesManagement;
    begin
        if POSTransaction.get(LSCPosTransaction."Receipt No.") then;
        PosTransLine.Reset();
        PosTransLine.SetRange("Receipt No.", LSCPosTransaction."Receipt No.");
        if PosTransLine.find('-') then
            repeat
                if (strpos(PosTransLine.Description, 'Solicito') > 0) or (strpos(PosTransLine.Description, 'Solicitud de cliente') > 0) then begin
                    if strpos(PosTransLine.Description, 'Crédito fiscal') > 0 then begin
                        if (POSTransaction."FSN Document Type" <> POSTransaction."FSN Document Type"::"Credito Fiscal") then begin
                            if POSTransaction."Retrieved from Receipt No." = '' then
                                if Terminal.Get(POSTransaction."POS Terminal No.") then begin
                                    POSTransaction."FSN Document Type" := POSTransaction."FSN Document Type"::"Credito Fiscal";
                                    POSTransaction."FSN No. Serie NCF" := Terminal."FSN No. Serie Credito Fiscal";
                                    nos.Reset();
                                    nos.SetRange("Series Code", Terminal."FSN No. Serie Credito Fiscal");
                                    if Nos.FindFirst() then begin
                                        POSTransaction."FSN NCF" := NoSeriesMgt.GetNextNo(nos."Series Code", Today, true);
                                        POSTransaction."FSN Correlative" := POSTransaction."FSN NCF";
                                    end;
                                    POSTransaction.Modify();
                                    POSSession.SetValue('DocTrans', FORMAT(POSTransaction."FSN Document Type"::"Credito Fiscal"));
                                    exit(true);
                                end;
                        end;
                    end;

                    if StrPos(PosTransLine.Description, 'Factura') > 0 then begin
                        if (POSTransaction."FSN Document Type" = POSTransaction."FSN Document Type"::Ticket) then begin
                            if POSTransaction."Retrieved from Receipt No." = '' then
                                if Terminal.Get(POSTransaction."POS Terminal No.") then begin
                                    POSTransaction."FSN Document Type" := POSTransaction."FSN Document Type"::Factura;
                                    POSTransaction."FSN No. Serie NCF" := Terminal."FSN No. Serie NCF Cons. Final";
                                    nos.Reset();
                                    nos.SetRange("Series Code", Terminal."FSN No. Serie NCF Cons. Final");
                                    if Nos.FindFirst() then begin
                                        POSTransaction."FSN NCF" := NoSeriesMgt.GetNextNo(nos."Series Code", Today, true);
                                        POSTransaction."FSN Correlative" := POSTransaction."FSN NCF";
                                    end;
                                    POSTransaction.Modify();
                                    POSSession.SetValue('DocTrans', FORMAT(POSTransaction."FSN Document Type"::Factura));
                                    exit(true);
                                end;
                        end;
                    end;
                end;
            until PosTransLine.Next() = 0;
    end;

    //Valida que no haya items sin pendiente de confirmar
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Transaction Events", 'OnBeforeTotalExecuted', '', true, true)]
    local procedure "LSC POS Transaction Events_OnBeforeTotalExecuted"
    (
     var POSTransaction: Record "LSC POS Transaction";
     var IsHandled: Boolean
    )
    var
        lText000: Label 'Tiene lineas pendientes de cofirmar';
        lText001: Label 'Tiene que adjuntar receta para productos controlados';
        lText002: Label 'No puede facturar productos marcados como RECETARIO en tiendas diferentes a F01';
        pErrorText: text;
        pREC: Record "LSC POS Transaction";
        POSTransC: Codeunit "LSC POS Transaction";
        menuLine: Record "LSC POS Menu Line";
        Recetas: Page Recetas;
        ItemStatus: Record "LSC Item Status Link";
        PosTransLine: Record "LSC POS Trans. Line";
        StoreGroupSetup: Record "LSC Store Group Setup";
    begin
        PosTransLine.Reset();
        PosTransLine.SetRange("Receipt No.", POSTransaction."Receipt No.");
        PosTransLine.SetRange("Entry Status", PosTransLine."Entry Status"::" ");
        PosTransLine.SetRange("Entry Type", PosTransLine."Entry Type"::Item);
        if PosTransLine.Find('-') then begin
            repeat
                ItemStatus.Reset();
                ItemStatus.SetRange("Item No.", PosTransLine.Number);
                ItemStatus.SetRange("Status Code", 'RECETARIO');
                if ItemStatus.FindFirst() then begin
                    StoreGroupSetup.Reset();
                    StoreGroupSetup.SetRange("Store Group", ItemStatus."Store Group Code");
                    StoreGroupSetup.SetRange("Store Code", POSTransaction."Store No.");
                    IF StoreGroupSetup.FindFirst() THEN begin
                        IsHandled := true;
                        Message(lText002);
                        exit;
                    end;
                end;
            until PosTransLine.Next() = 0;
        end;

        RequestID := 'FSNCC';
        Processed := false;
        FSNUtility.InvokeGlobalChannel(XMLRequest, XMLResponse, RequestID, PosMenuLineTemp, Processed, MsgResult);
        If not Processed then begin
            if ValidateControl(POSTransaction) then begin
                if pREC.Get(POSTransaction."Receipt No.") then begin
                    Message(lText001);
                    IsHandled := true;
                    exit;
                end;
            end;
        end;

        if ValidateRegTransaction(POSTransaction) then begin
            IsHandled := true;
            exit;
        end;

        POSSession.SetValue('DELETE', '');
        if ClientHaveCredit(POSTransaction) then
            showPanelMsg('Al pagar al credito se cambiaran los descuentos');

        //15837123
        if ValidateCredictCustomer(POSTransaction) then begin
            IsHandled := true;
            exit;
        end;

        //validacion de estado en la pos transaction
        IF POSTransaction."Entry Status" <> POSTransaction."Entry Status"::" " then begin
            POSTransaction."Entry Status" := POSTransaction."Entry Status"::" ";
            POSTransaction.Modify(true);
        end;

        if ValidateType(POSTransaction) then begin
            menuLine.Command := 'CANCEL2';
            POSTransC.run(menuLine);
            exit;
        end;

        //Validaciones de tipologia
        if Tipologia0(POSTransaction, pErrorText) then begin
            IsHandled := true;
            ERROR(pErrorText);
        end;
        //15837
        RequestID := 'FSNCC';
        Processed := false;
        FSNUtility.InvokeGlobalChannel(XMLRequest, XMLResponse, RequestID, PosMenuLineTemp, Processed, MsgResult);
        If not Processed then begin
            if DeleteLinevoided(POSTransaction) then begin
                menuLine.Command := 'CANCEL2';
                POSTransC.run(menuLine);
                IsHandled := true;
                exit;
            end;
        end;

        //* Recalculo de precios por cliente
        if not POSTransaction."Sale Is Return Sale" then
            if (EvaluateIsNeedReAddCust(POSTransaction)) or (ValVATGroup(POSTransaction)
            or ((POSTransaction."FSN Document Type" = POSTransaction."FSN Document Type"::"Credito Fiscal"))) AND (POSSession.GetValue('CHANGEGRO') <> 'TRUE') then
                RecalculatePrices(POSTransaction."Customer No.", POSTransaction, IsHandled);

        //* Cambio de Fecha de Transaccion
        if POSTransaction."Receipt No." <> '' then begin
            POSTransaction."Trans. Date" := Today;
            POSTransaction."Trans Time" := Time;
            POSTransaction.Modify(true);
        end;

        if NOT IsHandled then
            IsHandled := LinePendingConfirmScannExists(POSTransaction."Receipt No.");

        if NOT IsHandled then
            ValidateSaleIsReturnSale(POSTransaction);

        if NOT IsHandled then
            IsHandled := VerifyAuthorizeControler(POSTransaction);

        if NOT IsHandled then
            IsHandled := ConfirmReceta(POSTransaction);

        if NOT IsHandled then
            IsHandled := ValidateExpireDate(POSTransaction);

        IF (POSSession.GetValue('CHANGEGRO') = 'TRUE') THEN
            POSSession.SetValue('CHANGEGRO', 'FALSE');

        //110725
        if NOT IsHandled then
            IsHandled := ValGiftCardProcess(POSTransaction);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Create New Customer", 'SaveCustomerInfo_OnBeforeModify', '', true, true)]
    local procedure "LSC POS Create New Customer_SaveCustomerInfo_OnBeforeModify"
    (
        var lCustomerRec: Record "Customer";
        var CustomerRec: Record "Customer"
    )
    var
        RestricOption_l: Option;
        PosTransLine: Record "LSC POS Trans. Line";
        Customer: Record Customer;
    begin
        lCustomerRec."FSN Address" := CustomerRec."FSN Address";
        lCustomerRec."FSN Birthday" := CustomerRec."FSN Birthday";
        lCustomerRec."FSN Customer Type" := CustomerRec."FSN Customer Type";
        lCustomerRec."FSN Customer VAT Type" := CustomerRec."FSN Customer VAT Type";
        lCustomerRec."FSN DUI" := CustomerRec."FSN DUI";
        lCustomerRec."FSN EBS Reference" := CustomerRec."FSN EBS Reference";
        lCustomerRec."FSN Foreign document" := CustomerRec."FSN Foreign document";
        lCustomerRec."FSN Gender" := CustomerRec."FSN Gender";
        lCustomerRec."FSN Insurer" := CustomerRec."FSN Insurer";
        lCustomerRec."FSN Item Restricted" := CustomerRec."FSN Item Restricted";
        lCustomerRec."FSN Legal Representative" := CustomerRec."FSN Legal Representative";
        lCustomerRec."FSN Request Beneficiary" := CustomerRec."FSN Request Beneficiary";
        lCustomerRec."FSN NRC" := CustomerRec."FSN NRC";
        lCustomerRec."FSN NRC Description" := CustomerRec."FSN NRC Description";
        lCustomerRec."VAT Registration No." := CustomerRec."VAT Registration No.";
        lCustomerRec."E-Mail" := CustomerRec."E-Mail";
        lCustomerRec."Phone No." := CustomerRec."Phone No.";
        lCustomerRec."FSN Customer VAT Type" := CustomerRec."FSN Customer VAT Type";
        if not Utility.ValidateExtraCustomer('', false, false, CustomerRec, ErrorText, RestricOption_l) then begin
            ERROR(ErrorText);
            EXIT;
        end;
        if Customer.get(CustomerRec."No.") then begin
            if Customer.Name <> CustomerRec.Name then begin
                PosTransLine.Reset();
                PosTransLine.SetRange(PosTransLine."Receipt No.", POSTransC.GetReceiptNo());
                PosTransLine.SetRange(PosTransLine."Text Type", PosTransLine."Text Type"::"Cust. Text");
                PosTransLine.SetRange(PosTransLine."Card/Customer/Coup.Item No", CustomerRec."No.");
                if PosTransLine.FindFirst() then begin
                    PosTransLine.Description := 'Cliente: ' + CustomerRec.Name;
                    PosTransLine.Modify(true);
                end;
            end;
        end;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Refund Mgt.", 'OnBeforeCreateLinesToRefund', '', true, true)]
    local procedure "LSC POS Refund Mgt._OnBeforeCreateLinesToRefund"
    (
        var SelectionBuffer: Record "LSC POS Trans. Line";
        var POSTransLineBuffer: Record "LSC POS Trans. Line";
        var IsHandled: Boolean;
        var ReturnValue: Boolean
    )
    var
        OriginalTransaction: Record "LSC Transaction Header";

        CurrDate: Date;
        ResultDate: Integer;
        lText000: Label 'No se puede realizar la operación. La venta excede el limite de tiempo permitido para devolución';
    begin

        if POSTransLineBuffer.Get(SelectionBuffer."Receipt No.", SelectionBuffer."Line No.") then;

        OriginalTransaction.reset;
        OriginalTransaction.SetRange("Store No.", POSTransLineBuffer."Orig. Trans. Store");
        OriginalTransaction.SetRange("Transaction No.", POSTransLineBuffer."Orig. Trans. No.");
        OriginalTransaction.SetRange("POS Terminal No.", POSTransLineBuffer."Orig. Trans. Pos");
        if OriginalTransaction.FindFirst then begin
            CurrDate := CalcDate('<2M+CM>', OriginalTransaction.Date);
            IF (CurrDate < Today()) THEN BEGIN
                POSGUI.PosMessage(lText000);
                IsHandled := true;
                exit;
            end;
        end;
    end;
    //valida si hay que confirmar y bloquea si es delivery
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Transaction", 'OnItemNoPressed', '', true, true)]
    local procedure "LSC POS Transaction_OnItemNoPressed"
    (
        REC: Record "LSC POS Transaction";
        CurrInput: Text;
        var Handled: Boolean
    )
    var
        ValidateItem: Boolean;
        pErrorText: text;
        pExitOnly: boolean;
        PosView: Codeunit "LSC POS View";
        CurrItem: Text;
    begin

        if ValidateUniqueCoupon(CurrInput, REC) then begin
            Handled := true;
            exit;
        end;

        if LinePendingConfirmScannExists(REC."Receipt No.") then begin
            ValidateItemPendingScann(REC, COPYSTR(CurrInput, 1, 20), '', '', REC."Sales Staff", ErrorText, _ExitOnly);
            Handled := true;
            POSTransC.SetCurrInput(CurrItem);
            exit;
        END;

        if not BlockEditDeliveryOrder(REC, pErrorText, pExitOnly) then begin
            POSGUI.PosMessage(pErrorText);
            Handled := true;
            exit;
        end;

        /////////////////rework/////////////////////
        if POSSession.GetValue('FirstPass') = 'true' then begin
            if ValidateControllledProduct(CurrInput) then begin
                Handled := true;
                exit;
            end;
        end else begin
            POSSession.SetValue('FirstPass', 'true');
        end;
    end;

    //Muestra valor de cambio en efetivo
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Post Utility", 'OnAfterPostTransaction', '', true, true)]
    local procedure "LSC POS Post Utility_OnAfterPostTransaction"(var TransactionHeader_p: Record "LSC Transaction Header")
    var
        Text010: Label 'Change: $%1';
    begin
        //* Cambio de Fecha en la transaccion
        if TransactionHeader_p."Receipt No." <> '' then begin
            TransactionHeader_p.Date := Today;
            TransactionHeader_p.Time := Time;
            TransactionHeader_p.Modify(true);
        end;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Transaction Events", 'OnBeforeItemLine', '', true, true)]
    local procedure "LSC POS Transaction Events_OnBeforeItemLine"
    (
        var POSTransaction: Record "LSC POS Transaction";
        var POSTransLine: Record "LSC POS Trans. Line";
        var CurrInput: Text
    )
    var
        AllowItem: Record "FSN Allow/Deny Item Sales";
        Barcode: Record "LSC Barcodes";
        POSLine: Record "LSC POS Trans. Line";
        Staff: Record "LSC Staff";
        POSTransactionCodeunit: Codeunit "LSC POS Transaction";
        XMLRequest: Text;
        XMLResponse: Text;
        RequestID: Text[50];
        PosMenuLineTemp: Record "LSC POS Menu Line";
        Processed: Boolean;
        MsgResult: Text;
        FSNUtility: Codeunit "FSN Utility";
        DelOr: Record "LSC Delivery Order";
    begin
        IF Barcode.GET(CurrInput) THEN
            CurrInput := Barcode."Item No.";

        IF NOT
        AllowItem.ValidateSessionStaff(CurrInput, POSTransLine."Receipt No.", POSTransaction."Sales Staff", ErrorText) then begin
            CurrInput := '';
            POSGUI.PosMessage(ErrorText);
        end;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Transaction Events", 'OnBeforeSetFunctionModeSalesPressed', '', true, true)]
    local procedure "LSC POS Transaction Events_OnBeforeSetFunctionModeSalesPressed"
    (
        POSFuncProfile: Record "LSC POS Func. Profile";
        POSTransaction: Record "LSC POS Transaction";
        Keyed: Boolean;
        var CurrInput: Text;
        var IsHandled: Boolean
    )
    VAR
        POSSession: Codeunit "LSC POS Session";
    begin
        POSSession.SetValue('FSNLASTRCPTSSTAFF', POSTransaction."Receipt No.");
    end;

    //corrige error al cobrar vip
    [EventSubscriber(ObjectType::Table, Database::"LSC Report Temp Table", 'OnBeforeInsertEvent', '', true, true)]
    local procedure "LSC Report Temp Table_OnBeforeInsertEvent"
    (
        var Rec: Record "LSC Report Temp Table";
        RunTrigger: Boolean
    )
    var
        KeyValue: Code[30];
        Lookup: Record "LSC POS Lookup";
    begin
        Lookup.Reset;
        IF Rec.IsTemporary then
            IF POSSESSION.GetPosLookupRec('TENDOFFER', Lookup) THEN BEGIN
                KeyValue := POSSession.GetValue('#TENDERTEMP');
                if KeyValue <> '' then begin
                    Rec."User ID" := KeyValue;
                end;
            END;
    end;

    //bloqueo de botones para delivery
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Controller", 'OnPOSCommand', '', true, true)]
    local procedure "LSC POS Controller_OnPOSCommand"
    (
        var ActivePanel: Record "LSC POS Panel";
        var PosMenuLine: Record "LSC POS Menu Line"
    )
    var
        pREC: Record "LSC POS Transaction";
        pErrorText: text;
        pExitOnly: Boolean;
        EPosCtrl: Codeunit "LSC POS Control Interface";
        RC: Code[20];
        ERROR00: Label 'No es permitido cambiar tipo de documento en devoluciones';
    begin
        if (PosMenuLine.Command = 'SHOWPANEL') and (PosMenuLine."Parameter" = '#POS') then
            if pREC.Get(POSSESSION.GetValue('CURRORDER')) then
                ValidateDocumentType(pREC);


        if PosMenuLine.Command in ['VIEW_CUSTOMER', 'VOID_L', 'PRICECH', 'QTYCH', 'PLU_K', 'REMISSION_CO', 'REMISSION_INVOICE', 'CUPON', 'MEMBERCARD'] then begin
            pREC.Reset();
            if pREC.Get(POSTransC.GetReceiptNo()) then
                if not BlockEditDeliveryOrder(pREC, pErrorText, pExitOnly) then begin
                    POSGUI.PosMessage(pErrorText);
                    PosMenuLine.Processed := true;
                end;
        end;

        if PosMenuLine.Command = 'TOTAL' then begin
            pREC.Reset();
            if pREC.Get(POSTransC.GetReceiptNo()) then
                CheckTracker(pREC, PosMenuLine);
        end;

        if PosMenuLine.Command = 'START' then begin
            pREC.Reset();
            if pREC.Get(POSTransC.GetReceiptNo()) then begin
                if ValidateTransactionH(pREC) then begin
                    RC := IncStr(LasPostReceip());
                    InsertTmpTrans(RC, POSSESSION.WorkShiftNo, '', 0, false, '');
                end else
                    ValidateCouponVipTenderTyp5(pREC);
            end;
        end;

        if (PosMenuLine.Command = 'MGRKEY') and (PosMenuLine."Post Parameter" = 'MENU7') then begin
            pREC.Reset();
            if pREC.Get(POSTransC.GetReceiptNo()) then begin
                if ValidateTransactionH(pREC) then begin
                    RC := IncStr(LasPostReceip());
                    InsertTmpTrans(RC, POSSESSION.WorkShiftNo, '', 0, false, '');
                end;
            end;
        end;

        IF PosMenuLine.Command in ['NCFCRF', 'NCFFCF'] THEN begin
            pREC.Reset();
            if pREC.Get(POSTransC.GetReceiptNo()) then
                if pREC."Sale Is Return Sale" then begin
                    POSGUI.PosMessage(ERROR00);
                    PosMenuLine.Processed := true;
                end;
        end;
    end;

    procedure LasPostReceip(): Code[20]
    var
        myInt: Integer;
        Transaction: Record "LSC Transaction Header";
        PosTrans: Record "LSC POS Transaction";
        TmpLastSlip: Text[30];
        FilterFrom: Text[30];
        FilterTo: Text[30];
        ExistingReceiptNo: Code[20];
        POSFUNC: Codeunit "LSC POS Functions";
        LastSlipNo, RC : Code[20];
        Ws: Record "FSN WebServiceTable";
    begin
        LastSlipNo := '0';

        TmpLastSlip := POSFUNC.ZeroPad(POSSESSION.TerminalNo, 10) + POSFUNC.ZeroPad(LastSlipNo, 9);
        Transaction.SetCurrentKey("Receipt No.");

        FilterFrom := POSFUNC.ZeroPad(POSSESSION.TerminalNo, 10) + POSFUNC.ZeroPad('0', 9);
        FilterTo := POSFUNC.ZeroPad(POSSESSION.TerminalNo, 10) + POSFUNC.NumberPad('9', 9);
        Transaction.SetRange("Receipt No.", FilterFrom, FilterTo);
        ExistingReceiptNo := '';
        if Transaction.FindLast then
            if Transaction."Receipt No." > TmpLastSlip then begin
                ExistingReceiptNo := Transaction."Receipt No.";
                RC := IncStr(ExistingReceiptNo);
                if not ws.Get(RC) and (ws."WS Request" IN ['SEND_POSTRANS_BACKUP_BC', 'SEND_POSTRANS_BACKUP', '']) then begin
                    POSFUNC.WriteLocalVar(ExistingReceiptNo);
                    exit(ExistingReceiptNo);
                end else begin
                    POSFUNC.WriteLocalVar(RC);
                    exit(RC);
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
        PosTrans: Codeunit "LSC POS Transaction";
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
        PosTrans.SetPOSTransaction(TmpTrans);
        exit(TmpTrans."Receipt No.");
    end;

    local procedure ValidateTransactionH(PosTrans: Record "LSC POS Transaction"): Boolean
    var
        TransHeader: Record "LSC Transaction Header";
        PosTransD: Record "LSC POS Transaction";
    begin
        TransHeader.Reset();
        TransHeader.SetRange("Receipt No.", PosTrans."Receipt No.");
        TransHeader.SetRange("POS Terminal No.", PosTrans."POS Terminal No.");
        if TransHeader.FindFirst() then begin
            if PosTransD.Get(PosTrans."Receipt No.") then
                PosTrans.Delete(true);
            Commit();
            exit(true);
        end else
            exit(false);
    end;

    //Valida saldo de la giftcard
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Infocode Utility", 'OnBeforeDataEntryCheckVoucherRemainingAmt', '', true, true)]
    local procedure "LSC POS Infocode Utility_OnBeforeDataEntryCheckVoucherRemainingAmt"
    (
        MgrKeyActive: Boolean;
        RLineAmount: Decimal;
        var Line: Record "LSC POS Trans. Line";
        var Trans: Record "LSC POS Transaction";
        var DataEntry: Record "LSC POS Data Entry";
        var DataEntryType: Record "LSC POS Data Entry Type";
        PosFuncProfile: Record "LSC POS Func. Profile";
        var ErrorText: Text;
        var SkipCheck: Boolean;
        var IsHandled: Boolean;
        var ReturnValue: Boolean
    )
    var
        Text034: Label 'El saldo no es suficiente, el saldo actual es %1. Presione Atrás para cancelar';

    begin
        IF NOT IsHandled THEN begin
            if DataEntry."Voucher Remaining Amount" - RLineAmount < 0 then begin
                POSGUI.PosMessage(StrSubstNo(Text034, DataEntry."Voucher Remaining Amount"));
                IsHandled := TRUE;
                ReturnValue := FALSE;
            end;
        end;
    end;

    //Convierte en negativo el monto en voucher
    [EventSubscriber(ObjectType::Table, Database::"LSC Voucher Entries", 'OnBeforeInsertEvent', '', true, true)]
    local procedure "LSC Voucher Entries_OnBeforeInsertEvent"
     (
         var Rec: Record "LSC Voucher Entries";
         RunTrigger: Boolean
     )
    var
        DataEntryType: Record "LSC POS Data Entry Type";
        ReturnPosTransaction: Record "LSC POS Transaction";
    begin
        ReturnPosTransaction.reset;
        if ReturnPosTransaction.get(Rec."Receipt Number") then begin
            if not ReturnPosTransaction."Sale Is Return Sale" then begin
                DataEntryType.Get(Rec."Voucher Type");
                if DataEntryType."Create Voucher Entry" then begin
                    if Rec."Entry Type" <> Rec."Entry Type"::Issued then begin
                        IF Rec.Amount > 0 THEN
                            Rec.Amount := Rec.Amount * -1;
                        RunTrigger := true;
                    END;
                END;
            end;
        end;
    end;

    //Cambia el monto de voucher
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Transaction Events", 'OnAfterValidateChangePrice', '', true, true)]
    local procedure "LSC POS Transaction Events_OnAfterValidateChangePrice"
       (
           var POSTransaction: Record "LSC POS Transaction";
           var POSTransLine: Record "LSC POS Trans. Line";
           var CurrInput: Text;
           var Proceed: Boolean
       )
    var
        VoucherEntries_l: Record "LSC Voucher Entries";
        Price: Integer;
    begin
        IF VoucherEntries_l.GET(POSTransLine."Store No.", POSTransLine."POS Terminal No.", 0, POSTransLine."Line No.", POSTransLine."Receipt No.") THEN BEGIN
            IF CurrInput <> '' THEN begin
                Evaluate(Price, CurrInput);
                VoucherEntries_l.Amount := Price;
                VoucherEntries_l.MODIFY(TRUE);
            end;
        END;
    end;

    //se corrige error con devoluciones con ofertas
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Refund Mgt.", 'OnBeforeSalesEntryPosTransLineBufferInsert', '', true, true)]
    local procedure "LSC POS Refund Mgt._OnBeforeSalesEntryPosTransLineBufferInsert"
    (
        var POSTransLineBuffer: Record "LSC POS Trans. Line";
        TransLineEntry: Record "LSC Trans. Sales Entry"
    )
    var
        OriginalTransaction: Record "LSC Transaction Header";
    begin
        OriginalTransaction.reset;
        OriginalTransaction.SetRange("Store No.", POSTransLineBuffer."Orig. Trans. Store");
        OriginalTransaction.SetRange("Transaction No.", POSTransLineBuffer."Orig. Trans. No.");
        OriginalTransaction.SetRange("POS Terminal No.", POSTransLineBuffer."Orig. Trans. Pos");
        if OriginalTransaction.FindFirst then begin
            POSTransLineBuffer."Line No." := TransLineEntry."Line No.";
        end;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Transaction Events", 'ItemLineOnAfterItemGet', '', true, true)]
    local procedure "LSC POS Transaction Events_ItemLineOnAfterItemGet"
    (
        var POSTransLine: Record "LSC POS Trans. Line";
        var Proceed: Boolean;
        Item: Record "Item";
        var LastItemNo: Code[20]
    )
    var
        POSTransactionCodeunit: Codeunit "LSC POS Transaction";
        itemUnitOfMeasure: Record "Item Unit of Measure";
        EposInterface: Codeunit "LSC POS Control Interface";
        ItemUOM: Record "Item Unit of Measure";
        ProductExt: codeunit "LSC Product Ext.";
        TEXT000: Label 'Unidad de medida producto no encontrado.';

    begin
        IF NOT (POSSession.GetValue(SET_UOM_VALUE) = 'true') THEN BEGIN
            itemUnitOfMeasure.Reset();
            itemUnitOfMeasure.SetRange("Item No.", POSTransLine.Number);
            //ItemUnitofMeasure.SetFilter(ItemUnitofMeasure."LSC POS Selection", '<>%1', ItemUnitofMeasure."LSC POS Selection"::"Not Allowed");
            if itemUnitOfMeasure.Find('-') then
                if (itemUnitOfMeasure.Count > 1) then begin
                    ItemUOM.Reset;
                    ItemUOM.SetRange("Item No.", POSTransLine.Number);
                    ProductExt.FilterOnValidUOMPricesInStore(ItemUOM, POSTransLine.Number, POSTransLine."Store No.", '');
                    if (ItemUOM.Count >= 1) then begin
                        POSSession.SetValue(SET_UOM_VALUE, 'true');
                        POSSession.SetValue(PASS_ADMIN, 'Evaluate');
                        POSSession.SetValue('ITEMUOMFSN', POSTransLine.Number);
                        POSSession.SetValue(CURRENT_UOM, POSTransactionCodeunit.UOMPopUp(POSTransLine));
                        Proceed := false;
                    END ELSE begin
                        POSSession.SetValue(SET_UOM_VALUE, 'false');
                        POSSession.SetValue('ITEMUOMFSN', '');
                        Message(TEXT000);
                        Proceed := false;
                    end;
                end else begin
                    POSSession.SetValue('ITEMUOMFSN', POSTransLine.Number);
                    POSTransactionCodeunit.UnitOfMeasurePressed(itemUnitOfMeasure.Code);
                end;
        end;
    END;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Transaction Events", 'OnAfterItemLine', '', false, false)]
    local procedure OnAfterItemLine(var POSTransaction: Record "LSC POS Transaction"; var POSTransLine: Record "LSC POS Trans. Line"; var CurrInput: Text);
    var
        Item: Record Item;
        ItemCode, UOMCode, RequestID, msgResult : Text;
        FSNUtility: Codeunit "FSN Utility";
        passAdmin: Text;
        isBlocked: Boolean;
        PosMenu: Record "LSC POS Menu Line";
    begin
        //? Evaluar si la unidad de Medida esta bloqueada para el producto
        IF Item.GET(POSSession.GetValue('ITEMUOMFSN')) THEN
            ItemCode := Item."No.";
        //UOMCode := EposInterface.
        RequestID := 'UOM_VERIFY';
        UOMCode := POSSESSION.GetValue('VALUOMFSN');
        if UOMCode = '' then begin
            UOMCode := POSTransLine."Unit of Measure";
            POSSESSION.SetValue('VALUOMFSN', UOMCode);
        end;

        //? Verificar si el producto esta bloqueado por unidad de medida
        FSNUtility.InvokeGlobalChannel(ItemCode, UOMCode, RequestID, PosMenu, isBlocked, msgResult);

        if isBlocked then begin
            POSSession.SetValue('ITEMLOGIN', ItemCode);
            eposInterface.ShowPanelModal('#FSNLOGIN', 'LINEUNITFSN');
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
        Manager: Boolean;
        StaffID: Text;
        Password: Text;
        Workshift: Text;
        SetNewStaffID: Text;
        pReasonText: Text[80];
        ePOSControlInterface: Codeunit "LSC POS Control Interface";
        tStaff: Record "LSC Staff";
        Text019: Label 'Error in credentials %1';
        lText002: Label 'User %1 is not RETAIL MANAGER';
        pInt: Integer;
        POSInfocodeEntryC: Codeunit "LSC POS Infocode Utility";
        infocoRec: Record "LSC Infocode";
        ProdDescription: Label '%1 %2';
        ValueItemDescription: Text;
        TransLine: Record "LSC POS Trans. Line";
        Canceled: Boolean;
        TSError: boolean;
        EntryLineNo: integer;
        TransInfoEntry: Record "LSC POS Trans. Infocode Entry";
        POSTransactionVal: Record "LSC POS Transaction";
        Processedv: boolean;
    begin
        //Se invoca el procedimiento ValidateUnitOfme para validar unidad de medida
        if (payload = '{"j":{"POPUPTYPE":"POPUPUOM","BOOLEAN":"0"},"t":"10000735"}') and (panelID = '#POP-SIMPLE') then begin
            if resultOK then begin
                if POSSession.GetValue(SET_UOM_VALUE) = 'true' then begin
                    POSSession.SetValue(SET_UOM_VALUE, 'false');
                    POSSession.SetValue('FSN_Barcode', '');
                end;
            end ELSE
                POSSession.SetValue(SET_UOM_VALUE, 'false');
        end;

        //VALIDA LOGIN PARA UNIDAD DE MEDIDA BLOQUEADA
        if (payload IN ['LINEUNITFSN', 'CONTROLLEDPRODUCT']) and (panelID = '#FSNLOGIN') then begin
            if resultOK then begin
                Manager := true;
                StaffID := ePOSControlInterface.GetInputText(POSSession.StaffInputID);
                Password := ePOSControlInterface.GetInputText(POSSession.PasswordInputID);
                Workshift := CopyStr(ePOSControlInterface.GetInputText(POSSession.WorkShiftInputID), 1, 1);
                if StaffID = '' then begin
                    processed := true;
                    VoidedLine();
                    exit;
                end;
                SetNewStaffID := StaffID;
                tStaff.Reset();
                tStaff.SetCurrentKey(ID);
                tStaff.SetRange(ID, StaffID);
                tStaff.SetRange("Permission Group", 'MANAGER');
                IF NOT (tStaff.FINDFIRST) AND (EVALUATE(pInt, StaffID)) THEN BEGIN
                    VoidedLine();
                    processed := true;
                    ePOSControlInterface.SetInputText(POSSession.StaffInputID, '');
                    ePOSControlInterface.SetInputText(POSSession.PasswordInputID, '');
                    POSGUI.PosMessage(STRSUBSTNO(lText002, StaffID));
                    EXIT;
                END;

                if not POSSESSION.Login(true, StaffID, Password, Workshift, pReasonText) then begin
                    processed := true;
                    ePOSControlInterface.SetInputText(POSSession.StaffInputID, '');
                    ePOSControlInterface.SetInputText(POSSession.PasswordInputID, '');
                    VoidedLine;
                    //POSGUI.PosMessage(StrSubstNo(Text019, pReasonText));
                    exit;
                end;

                if infocoRec.Get('LOGINAUTHORIZE') THEN BEGIN//030725
                    if POSTransactionVal.get(POSTransC.GetReceiptNo()) then
                        SaveLoginAthorize(POSTransactionVal, TransInfoEntry, SetNewStaffID);
                    RequestID := 'FSNCC';
                    Processedv := false;
                    FSNUtility.InvokeGlobalChannel(XMLRequest, XMLResponse, RequestID, PosMenuLineTemp, Processedv, MsgResult);
                    If Processedv then begin
                        if POSSession.GetValue('TOTALOGIN') = 'TRUE' then
                            CheckInfocode(POSTransactionVal, true);
                    end;
                END;

                ePOSControlInterface.SetInputText(POSSession.StaffInputID, '');
                ePOSControlInterface.SetInputText(POSSession.PasswordInputID, '');
                POSSession.SetValue('TOTALOGIN', '');
                POSSession.SetValue('ITEMUOMFSN', '');
                POSSession.SetValue('FSN_Barcode', '');
                POSSession.SetValue('ITEMLOGIN', '');
                if (payload IN ['LINEUNITFSN']) then
                    POSSession.SetValue(SET_UOM_VALUE, '');
            end else begin
                VoidedLine;
                processed := true;
            end;
        end;
    end;

    procedure SaveLoginAthorize(posTransacB: Record "LSC POS Transaction"; var InfoEntry: Record "LSC POS Trans. Infocode Entry"; StaffID: Text): Boolean
    var
        POSSession: Codeunit "LSC POS Session";
    begin
        InfoEntry.Init();
        InfoEntry."Store No." := posTransacB."Store No.";
        InfoEntry."POS Terminal No." := posTransacB."POS Terminal No.";
        InfoEntry."Receipt No." := posTransacB."Receipt No.";
        InfoEntry."Transaction Type" := 0;
        InfoEntry."Line No." := 91;
        InfoEntry.Infocode := 'LOGINAUTHORIZE';
        InfoEntry.Information := CopyStr(StaffID, 1, 100);
        InfoEntry."Source Code" := POSSession.GetValue('ITEMLOGIN');
        InfoEntry.Date := Today;
        InfoEntry.Time := Time;
        if not InfoEntry.Insert() then
            InfoEntry.Modify();
        exit(true);
    end;

    //FILTRA PRODUCTO Y UNIDAD DE MEDIDA PARA ANULAR LA LINEA SI NO SE CUMPLE
    procedure VoidedLine()
    var
        myInt: Integer;
        POSTransLine: Record "LSC POS Trans. Line";
    begin
        POSTransLine.Reset();
        POSTransLine.SetCurrentKey("Receipt No.", "Line No.");
        POSTransLine.SetRange("Receipt No.", POSTransC.GetReceiptNo());
        POSTransLine.SetRange(POSTransLine.Number, POSSession.GetValue('ITEMUOMFSN'));
        POSTransLine.SetRange(POSTransLine."Unit of Measure", POSSESSION.GetValue('VALUOMFSN'));
        POSTransLine.SetRange(POSTransLine."Entry Type", POSTransLine."Entry Type"::Item);
        if POSTransLine.FindLast() then
            POSTransLine.VoidLine();

        POSSession.SetValue('FSN_Barcode', '');
        POSSession.SetValue('ITEMUOMFSN', '');
        POSSession.SetValue('ITEMLOGIN', '');
        POSSession.SetValue(SET_UOM_VALUE, '');
        POSSession.SetValue('FirstPass', 'true');
        POSSession.SetValue('TOTALOGIN', '');
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Controller", 'OnPOSEvent', '', true, true)]
    local procedure "LSC POS Controller_OnPOSEvent"
    (
    var PosEvent: Codeunit "LSC POS Event";
    var SuppressEvent: Boolean
    )
    var
        POSSESSION: Codeunit "LSC POS Session";
        DeliveryOrder: Record "LSC Delivery Order";
        POSTransaction: Record "LSC POS Transaction";
        PosTransC: Codeunit "LSC POS Transaction";
        POSINFO: Record "LSC POS Trans. Infocode Entry";
        SalesType: Record "LSC Sales Type";
        POSLines: Codeunit "LSC POS Trans. Lines";
        POSLine_l: Record "LSC POS Trans. Line";
        POSInfocodeEntry: Record "LSC POS Trans. Infocode Entry";
        caption: Label 'RECETA: %1';
        Result: Action;
    begin
        //guarda en variable de session la unidad de medida selecionada.
        if (PosEvent.ActivePanel = '#POP-SIMPLE') then begin
            if POSSession.GetValue(SET_UOM_VALUE) = 'true' then begin
                POSSESSION.SetValue('VALUOMFSN', '');
                IF PosEvent.StrData2 <> '' THEN
                    POSSESSION.SetValue('VALUOMFSN', PosEvent.StrData2);
            end;
        end;

        if (PosEvent.ActivePanel = '#POS') and (PosEvent.StrData2() = 'Escape') then begin
            if not DeliveryOrder.Get(PosTransC.GetReceiptNo()) then
                if POSTransaction.Get(PosTransC.GetReceiptNo()) then begin
                    if validateLine(POSTransaction) then begin
                        if not POSINFO.Get(POSTransaction."Receipt No.", POSINFO."Transaction Type"::Header, 53, 'ESCTRANS', 0) then
                            MarkTransaction(POSTransaction, 'ESCTRANS', 'FACTURADA', 53);
                        PosTransC.SuspendTransaction(POSTransaction, SalesType);
                    end;
                end;
        end;

        if PosEvent.ActivePanel = '#POS' THEN
            if PosEvent.EventType in [
                Enum::"LSC POS Event Type"::DATAROWDOUBLECLICK
            ] then begin
                POSLines.GetCurrentLine(POSLine_l);
                if (POSLine_l."Entry Type" = POSLine_l."Entry Type"::FreeText) and (POSLine_l."Text Type" = POSLine_l."Text Type"::"Freetext Input") AND
                    (POSLine_l."Entry Status" = POSLine_l."Entry Status"::" ") and (((COPYSTR(POSLine_l.Description, 1, 9)) = 'N° RECETA')) THEN
                    if POSTransaction.get(POSLine_l."Receipt No.") then begin//030725
                        POSInfocodeEntry.Reset();
                        POSInfocodeEntry.SetRange(POSInfocodeEntry."Receipt No.", POSTransaction."Receipt No.");
                        POSInfocodeEntry.SetRange(POSInfocodeEntry.Infocode, 'NRECETA');
                        if POSInfocodeEntry.FindFirst() then begin
                            POSSession.SetValue('#NoReceta', 'TRUE');
                            POSSession.SetValue('#TransLineNoR', POSInfocodeEntry."Source Code");
                            POSGUI.OpenAlphabeticKeyboard(CopyStr(POSLine_l.Description, 1, 50), '', Result, true);
                        END;
                    end;
            end
    end;

    local procedure validateLine(postransaction: Record "LSC POS Transaction"): Boolean
    var
        myInt: Integer;
        POSTransLine: Record "LSC POS Trans. Line";
    begin
        POSTransLine.Reset();
        POSTransLine.SetRange("Receipt No.", postransaction."Receipt No.");
        POSTransLine.SetRange(POSTransLine."Entry Type", POSTransLine."Entry Type"::Item);
        POSTransLine.SetRange(POSTransLine."Entry Status", 0);
        if POSTransLine.Find('-') then
            exit(true);
    end;

    procedure MarkTransaction(posTrans: Record "LSC POS Transaction"; arg: Text; value: Text; Line_: Integer)
    var
        infocode: Record "LSC POS Trans. Infocode Entry";
    begin
        infocode.Init();
        infocode."Receipt No." := posTrans."Receipt No.";
        infocode."Transaction Type" := infocode."Transaction Type"::Header;
        infocode."Line No." := Line_;
        infocode.Infocode := arg;
        infocode.Information := value;
        infocode."POS Terminal No." := posTrans."POS Terminal No.";
        infocode."Store No." := posTrans."Store No.";
        infocode.Date := Today();
        infocode.Time := Time();
        infocode."Staff ID" := posTrans."Staff ID";

        if not infocode.Insert(true) then
            infocode.Modify(true);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Transaction Events", 'OnAfterCalcTotals', '', true, true)]
    local procedure "LSC POS Transaction Events_OnAfterCalcTotals"
    (
        var Rec: Record "LSC POS Transaction";
        var Balance: Decimal;
        var RealBalance: Decimal
    )
    var
        Balancet: Decimal;
        RealBalancet: Decimal;
    begin
        POSSession.SetValue('RealBalanceT', Format(Balance));
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Transaction Events", 'OnAfterTenderKeyExecutedEx', '', true, true)]
    local procedure "LSC POS Transaction Events_OnAfterTenderKeyExecutedEx"
    (
        var POSTransaction: Record "LSC POS Transaction";
        var POSTransLine: Record "LSC POS Trans. Line";
        var CurrInput: Text;
        var TenderTypeCode: Code[10];
        var TenderAmountText: Text
    )
    var
        XMLRequest: Text;
        XMLResponse: Text;
        RequestID: Text[50];
        PosMenuLineTemp: Record "LSC POS Menu Line" temporary;
        Processed: Boolean;
        MsgResult: text;
        FSNUtility: Codeunit "FSN Utility";
    begin
        //load 
        RequestID := 'FSNCC';
        Processed := false;
        FSNUtility.InvokeGlobalChannel(XMLRequest, XMLResponse, RequestID, PosMenuLineTemp, Processed, MsgResult);
        If Processed then
            if ((TenderTypeCode = '4') and not (POSTransaction."Sale Is Return Sale")) then
                if POSTransLine.Amount > 0 then begin
                    if POSTransaction."Customer No." <> '' then begin
                        Customer.Reset();
                        if Customer.Get(POSTransaction."Customer No.") then begin
                            LoadToCalculateFields(Customer, POSTransLine.Amount, false);
                        end;
                    end;
                end;
    end;

    [EventSubscriber(ObjectType::Table, Database::"LSC POS Trans. Line", 'OnAfterVoidLine', '', true, true)]//15837
    local procedure "LSC POS Trans. Line_OnAfterVoidLine"(var Rec: Record "LSC POS Trans. Line")
    var
        PosInfocode: Record "LSC POS Trans. Infocode Entry";
        WebS: Record "FSN WebServiceTable";
        Item: Record Item;
        POSTransaction: Record "LSC POS Transaction";
    begin
        Item.Reset();
        if Item.Get(Rec.Number) then
            if (StrPos(Item."LSC Attrib 2 Code", 'CONTROL') > 0) then begin
                GetReceta(Rec."Receipt No.");
                DelInf(Rec);
            end;
    end;

    local procedure DelInf(GlobalPosTransaction: Record "LSC POS Trans. Line")
    var
        myInt: Integer;
        transLine: Record "LSC POS Trans. Line";
    begin
        transLine.Reset();
        transLine.SetRange("Receipt No.", GlobalPosTransaction."Receipt No.");
        transLine.SetRange("POS Terminal No.", GlobalPosTransaction."POS Terminal No.");
        transLine.SetRange("Entry Type", transLine."Entry Type"::FreeText);
        transLine.setrange("Entry Status", transLine."Entry Status"::" ");
        transLine.SetFilter(Description, '*Receta registrada con ID:*');
        if transLine.FindFirst() then
            transLine.VoidLine();
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Transaction Events", 'OnBeforeInsertPayment_TenderKeyExecutedEx', '', true, true)]
    local procedure "LSC POS Transaction Events_OnBeforeInsertPayment_TenderKeyExecutedEx"
    (
        var POSTransaction: Record "LSC POS Transaction";
        var POSTransLine: Record "LSC POS Trans. Line";
        var CurrInput: Text;
        var TenderTypeCode: Code[10];
        var TenderAmountText: Text
    )
    var
        ValidateTender: Boolean;
        Step: Integer;
        POSTranCod: Codeunit "LSC POS Transaction";
        POSTransLineVal: Record "LSC POS Trans. line";
        MessageError: text;
    begin
        IF POSTransaction."Sale Is Return Sale" then begin
            ValidateTender := ValidateTenderTypeAmount(POSTransaction, TenderTypeCode, TenderAmountText, Step, POSTranCod.GetOutstandingBalance());
            if not ValidateTender then begin
                CurrInput := '';
            end;
        end;

        POSTransLineVal.Reset();
        POSTransLineVal.SetRange("Receipt No.", POSTransaction."Receipt No.");
        POSTransLineVal.SetRange(POSTransLineVal."Entry Status", 0);
        POSTransLineVal.SetRange("Entry Type", POSTransLineVal."Entry Type"::IncomeExpense);
        if POSTransLineVal.find('-') then begin
            repeat
                ValIncomeExpenseAndPayment(POSTransLineVal."Store No.", POSTransLineVal.Number, TenderTypeCode, MessageError);
                if MessageError <> '' then
                    Error(MessageError);
            until POSTransLineVal.Next() = 0;
        end;
    end;

    //Valida medias de pago permitidas para ingresoGasto
    procedure ValIncomeExpenseAndPayment(Store: Code[10]; NoIncExp: Code[20]; NoTenderType: Code[10]; var ErrorMessage: Text)
    var
        ValParameter: Record "FSN parameter";
        ValTenderType: Record "LSC Tender Type";
        ValIncExp: Record "LSC Income/Expense Account";
        TEXT000: label 'Media de pago %1 no es permitida con Cuenta Ingreso/Gasto %2.';
        XMLRequest: Text;
        XMLResponse: Text;
        RequestID: Text[50];
        PosMenuLineTemp: Record "LSC POS Menu Line" temporary;
        Processed: Boolean;
    begin
        ErrorMessage := '';
        RequestID := 'TENDER_INCEXP';
        XMLRequest := '{storeNo:''' + Store + ''',IncExpCode:''' + NoIncExp + ''',tenderK:''' + NoTenderType + '''}';
        FSNUtility.InvokeGlobalChannel(XMLRequest, XMLResponse, RequestID, PosMenuLineTemp, Processed, ErrorMessage);
    end;

    [EventSubscriber(ObjectType::Table, Database::"LSC POS Trans. Line", 'OnBeforeInsertEvent', '', true, true)]
    local procedure "LSC POS Trans. Line_OnBeforeInsertEvent"
    (
        var Rec: Record "LSC POS Trans. Line";
        RunTrigger: Boolean
    )
    var
        POSTransaction: Record "LSC POS Transaction";
        POSTranCod: Codeunit "LSC POS Transaction";
        Bal: Decimal;
        TEXT000: Label 'Monto de %1 excede el balance total que es $ %2';
        XMLRequest: Text;
        XMLResponse: Text;
        RequestID: Text[50];
        PosMenuLineTemp: Record "LSC POS Menu Line";
        Processed: Boolean;
        MsgResult: text;
        Barrecode: Record "LSC Barcodes";
        ItemSpGroupLink: Record "LSC Item/Special Group Link";
    begin
        //Validacion de balance total para giftcard 28981
        IF Rec."Entry Type" = Rec."Entry Type"::IncomeExpense THEN begin
            if Rec.Number = '12' then begin
                if POSTransaction.Get(Rec."Receipt No.") then
                    if not POSTransaction."Sale Is Return Sale" then begin
                        if not (POSTranCod.GetOutstandingBalance() IN [0, 0.00]) then begin
                            if (-Rec.Amount) > POSTranCod.GetOutstandingBalance() then
                                Error(STRSUBSTNO(TEXT000, Rec.Description, POSTranCod.GetOutstandingBalance()));
                        end;
                    end;
            end;
        end;

        RequestID := 'FSNCC';
        Processed := false;
        FSNUtility.InvokeGlobalChannel(XMLRequest, XMLResponse, RequestID, PosMenuLineTemp, Processed, MsgResult);
        If Processed then begin
            if (Rec.Number <> '') and (Rec."Entry Type" = Rec."Entry Type"::Item) then begin
                Barrecode.Reset();
                Barrecode.SetRange("Item No.", Rec.Number);
                if Rec."Unit of Measure" <> '' then
                    Barrecode.SetRange("Unit of Measure Code", Rec."Unit of Measure");
                if Barrecode.FindFirst() then
                    Rec."Barcode No." := Barrecode."Barcode No.";
            end;
        end;

        if not Rec.IsTemporary then begin
            IF Rec."Entry Type" = Rec."Entry Type"::Item THEN//110725
                IF ItemSpGroupLink.Get(Rec.Number, 'MARGEN') THEN
                    Rec."Recommended Item" := true
                ELSE
                    Rec."Recommended Item" := false;
        end;
    end;



    [EventSubscriber(ObjectType::Table, Database::"LSC POS Trans. Infocode Entry", 'OnBeforeInsertEvent', '', true, true)]
    local procedure "LSC POS Trans. Infocode Entry_OnBeforeInsertEvent"
    (
        var Rec: Record "LSC POS Trans. Infocode Entry";
        RunTrigger: Boolean
    )
    var
        POSTransLine: Record "LSC POS Trans. Line";
        InfSubcode: Record "LSC Information Subcode";
        POSTransaction: Record "LSC POS Transaction";
    begin

        IF NOT Rec.IsTemporary THEN BEGIN//VARIANTES
            if POSTransaction.Get(Rec."Receipt No.") then
                IF ValInfocodeVariants(Rec, POSTransaction) THEN begin
                    if not (POSTransaction."Sale Is Return Sale") then begin
                        POSTransLine.Reset();
                        POSTransLine.SetRange("Receipt No.", Rec."Receipt No.");
                        POSTransLine.SetRange(POSTransLine."Line No.", Rec."Line No.");
                        POSTransLine.SetRange(POSTransLine.Number, Rec."Source Code");
                        IF POSTransLine.FINDFIRST THEN BEGIN
                            InfSubcode.Reset();
                            InfSubcode.SetRange(InfSubcode.Code, Rec.Infocode);
                            InfSubcode.SetRange(InfSubcode.Subcode, Rec.Information);
                            IF InfSubcode.FINDFIRST THEN BEGIN
                                IF POSSESSION.FunctionalityProfileID() <> '' then BEGIN
                                    Rec.Amount := InfSubcode."Amount /Percent";
                                    POSTransLine.Validate(POSTransLine.Price, InfSubcode."Amount /Percent");
                                    POSTransLine.Description := InfSubcode.Description;
                                    POSTransLine.CalcPrices();
                                    POSTransLine.Modify(true);
                                END;
                            END;
                        END;
                    end else
                        ReturnDescriptionVariants(POSTransaction);
                end;
        END;
    end;

    procedure ValInfocodeVariants(Rec: Record "LSC POS Trans. Infocode Entry"; LSCPOSTransaction: Record "LSC POS Transaction"): Boolean
    var
        myInt: Integer;
        POSTransLine: Record "LSC POS Trans. Line";
        LSCInfocode: Record "LSC Infocode";
    begin
        POSTransLine.Reset();
        POSTransLine.SetRange("Receipt No.", Rec."Receipt No.");
        if not LSCPOSTransaction."Sale Is Return Sale" then
            POSTransLine.SetRange(POSTransLine."Line No.", Rec."Line No.")
        else
            POSTransLine.SetRange(POSTransLine."Orig. Trans. Line No.", Rec."Line No.");
        POSTransLine.SetRange(POSTransLine.Number, Rec.Infocode);
        if POSTransLine.FindFirst() then begin
            if LSCInfocode.Get(Rec.Infocode) and (LSCInfocode.Prompt = 'VARIANTES') then
                exit(true)
            ELSE
                exit(false);

        end;
        exit(false);
    end;

    procedure ReturnDescriptionVariants(POSTransaction: Record "LSC POS Transaction")
    var
        myInt: Integer;
        TransInfocodeEntry: Record "lSC trans. infocode entry";
        POSTransLine: record "LSC POS Trans. Line";
        InfSubcode: Record "LSC Information Subcode";
        LSCInfocode: Record "LSC Infocode";
    begin

        POSTransLine.Reset();
        POSTransLine.SetRange("Receipt No.", POSTransaction."Receipt No.");
        POSTransLine.SetRange(POSTransLine."Entry Type", POSTransLine."Entry Type"::Item);
        IF POSTransLine.FIND('-') THEN BEGIN
            repeat
                TransInfocodeEntry.Reset;
                TransInfocodeEntry.SetRange("Store No.", POSTransaction."Retrieved from Store No.");
                TransInfocodeEntry.SetRange("POS Terminal No.", POSTransaction."Retrieved from POS Term. No.");
                TransInfocodeEntry.SetRange("Line No.", POSTransLine."Orig. Trans. Line No.");
                TransInfocodeEntry.SetRange("Transaction Type", TransInfocodeEntry."Transaction Type"::"Sales Entry");
                TransInfocodeEntry.SetRange(Infocode, POSTransLine.Number);
                if TransInfocodeEntry.FindFirst() then begin
                    if LSCInfocode.get(TransInfocodeEntry.Infocode) and (LSCInfocode.Prompt = 'VARIANTES') then begin
                        InfSubcode.Reset();
                        InfSubcode.SetRange(InfSubcode.Code, LSCInfocode.Code);
                        InfSubcode.SetRange(InfSubcode.Subcode, TransInfocodeEntry.Information);
                        IF InfSubcode.FINDFIRST THEN BEGIN
                            POSTransLine.Description := InfSubcode.Description;
                            POSTransLine.Modify(true);
                        END;
                    end;
                end;
            until POSTransLine.Next() = 0;
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
        TEXT001: Label 'Monto no puede ser negativo en ventas al credito';
        TEXT002: Label 'No se puede agregar linea de pago, el monto es $0.00';
    begin
        if not POSTransaction."Sale Is Return Sale" then begin
            if (Balance < 0.0) and (TenderTypeCode in ['4']) then begin
                isHandled := true;
                Message(TEXT001);
            end;
        end;

        if (Balance = 0.0) then begin
            isHandled := true;
            Message(TEXT002);
        end;
    end;

    //Evalua que no lleve mas de 13 lineas de productos
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Transaction Events", 'OnBeforeInsertItemLine', '', true, true)]
    local procedure "LSC POS Transaction Events_OnBeforeInsertItemLine"
    (
        var POSTransaction: Record "LSC POS Transaction";
        var POSTransLine: Record "LSC POS Trans. Line";
        var CurrInput: Text
    )
    var
        XMLRequest: Text;
        XMLResponse: Text;
        RequestID: Text[50];
        PosMenuLineTemp: Record "LSC POS Menu Line";
        Processed: Boolean;
        MsgResult: Text;
        DelOr: Record "LSC Delivery Order";
        PosTransLine2: Record "LSC POS Trans. Line";
        Cont: Integer;
        TexI01: Label 'Desea insertar mas de %1 lineas';
        ItemM: Integer;
        Item: Record Item;
    begin
        RequestID := 'FSNCC';
        Processed := false;
        FSNUtility.InvokeGlobalChannel(XMLRequest, XMLResponse, RequestID, PosMenuLineTemp, Processed, MsgResult);
        If Processed then begin
            Cont := 0;
            PosTransLine2.Reset();
            PosTransLine2.SetRange("Receipt No.", POSTransaction."Receipt No.");
            PosTransLine2.SetRange("Entry Status", PosTransLine2."Entry Status"::" ");
            PosTransLine2.SetRange("Entry Type", PosTransLine2."Entry Type"::Item);
            if PosTransLine2.Find('-') then begin
                repeat
                    if ((PosTransLine2.Description <> POSTransLine.Description) OR
                    (PosTransLine2."Unit of Measure" <> POSTransLine."Unit of Measure")) then
                        Cont += 1;
                    if Cont > 12 then
                        if POSSession.GetValue('FSNITEMLINE') = '' then
                            IF NOT CONFIRM(STRSUBSTNO(TexI01, Cont)) THEN begin
                                EXIT;
                            end else begin
                                POSSession.SetValue('FSNITEMLINE', 'SI')
                            end;
                until PosTransLine2.Next() = 0;
            end;
        end;
    end;


    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Controller", 'OnButtonPressed', '', true, true)]
    local procedure "LSC POS Controller_OnButtonPressed"
    (
        var POSMenuLine: Record "LSC POS Menu Line";
        var handled: Boolean
    )
    var
        POSTransaction: Record "LSC POS Transaction";
        DeliveryOrder: Record "LSC Delivery Order";
        TEXT000: Label 'No tiene los permisos para anular pedios Call Center';
        FSNParameter: Record "FSN Parameter";
        XMLRequest: Text;
        XMLResponse: Text;
        RequestID: Text[50];
        PosMenuLineTemp: Record "LSC POS Menu Line";
        Processed: Boolean;
        MsgResult: Text;
        FileMgt: Codeunit "File Management";
        OpenedFile: File;
        InStr: InStream;
        FileName: Text;
        Item: Record Item;
        Recetas: Page "Recetas";
    begin
        if (POSMenuLine.Command = 'INCEXP') and (POSMenuLine.Parameter = '12') then begin
            POSTransaction.Get(POSTransC.GetReceiptNo());
            if ValidatePaintmenCat(POSTransaction) then begin
                POSGUI.PosMessage('La venta contiene productos que solo puede ser registrados en efectivo.');
                handled := true;
                exit;
            end;
        end;

        if POSMenuLine.Command = 'HOSP-OPEN-POS-DIR' then begin
            POSTransaction.Reset();
            POSTransaction.SetFilter("Price Group Code", '<>DELIVERY&<>TAKEAWAY&<>PRE-ORDER&<>TAKEOUT');
            POSTransaction.SetRange("Entry Status", POSTransaction."Entry Status"::" ");
            POSTransaction.SetRange("POS Terminal No.", POSSession.TerminalNo());
            POSTransaction.SetRange("Trans. Date", Today);
            if POSTransaction.FindLast() then begin
                if not (deliveryOrder.Get(POSTransaction."Receipt No.") or POSTransaction."Sale Is Return Sale") then begin
                    PosTransaction."New Transaction" := true;
                    PosTransaction."Transaction Type" := PosTrans."Transaction Type"::Logoff;
                    PosTransaction.Modify();
                end;
            end;
        end;

        if POSMenuLine.Command = 'VOID' then begin
            DeliveryOrder.Reset();
            IF DeliveryOrder.Get(POSTransC.GetReceiptNo()) THEN BEGIN
                RequestID := 'FSNCC';
                Processed := false;
                FSNUtility.InvokeGlobalChannel(XMLRequest, XMLResponse, RequestID, PosMenuLineTemp, Processed, MsgResult);
                if not Processed then begin
                    if FSNParameter.Get('CALLCENTER', 'VOIDORDER') then
                        if FSNParameter.Activo then begin
                            Error(TEXT000);
                            handled := true;
                        end;
                end;
            END;
        end;

        //TENDER KEY validation
        if (POSMenuLine.Command = 'TENDER_K') and (POSMenuLine.Parameter = '4') then begin
            if validateTransactionDiscount() then begin
                handled := true;
                showPanelMsg('Se han actualizado los descuentos');
                exit;
            end;

            POSTransaction.Reset();
            if POSTransaction.Get(POSTransC.GetReceiptNo()) then begin
                IF NOT POSTransaction."Sale Is Return Sale" THEN
                    ValTenderKCreditCustomer(POSTransC.GetReceiptNo(), POSMenuLine.Parameter);
            end;
        end;

        if POSMenuLine.Command = 'RECETAADJ' then begin
            POSTransaction.Reset();
            if POSTransaction.Get(POSTransC.GetReceiptNo()) then begin
                IF POSTransaction."Customer No." <> '' then begin
                    if not ValidateITem(POSTransaction) then begin
                        Message('No hay productos en transacción');
                        exit;
                    end;
                    Recetas.GetPosTransaction(POSTransaction);
                    if Recetas.RunModal() = Action::LookupOK then;
                end else begin
                    Message('Debe agregar cliente a la transacción');
                end;
            end;
        end;
    END;

    local procedure ValidateITem(PostR: Record "LSC POS Transaction"): Boolean
    var
        myInt: Integer;
        PosTransLine: Record "LSC POS Trans. Line";
    begin
        PosTransLine.Reset();
        PosTransLine.SetRange("Receipt No.", PostR."Receipt No.");
        PosTransLine.SetRange("Entry Status", PosTransLine."Entry Status"::" ");
        PosTransLine.SetRange("Entry Type", PosTransLine."Entry Type"::Item);
        exit(PosTransLine.FindFirst());
    end;

    procedure ValTenderKCreditCustomer(Receipt: Code[20]; TenderKCod: Code[10])
    var
        PosTransLine: Record "LSC POS Trans. Line";
        TenderK: Record "LSC Tender Type";
        TEXT000: Label 'No se puede mezclar %1 con media de pago %2';
    begin
        PosTransLine.Reset();
        PosTransLine.SetRange(PosTransLine."Entry Type", PosTransLine."Entry Type"::Payment);
        PosTransLine.SetRange(PosTransLine."Receipt No.", Receipt);
        PosTransLine.SetRange("Entry Status", PosTransLine."Entry Status"::" ");
        PosTransLine.SETFILTER(PosTransLine.Number, '<>%1', '4');
        if PosTransLine.Find('-') then begin
            if TenderK.Get(PosTransLine."Store No.", TenderKCod) then
                Error(TEXT000, TenderK.Description, PosTransLine.Description);
        end;
    end;

    //AGREGA TIPO VENDEDOR
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Post Utility", 'SalesEntryOnBeforeInsert', '', true, true)]
    local procedure "LSC POS Post Utility_SalesEntryOnBeforeInsert"
    (
        var pPOSTransLine: Record "LSC POS Trans. Line";
        var pTransSalesEntry: Record "LSC Trans. Sales Entry"
    )
    var
        rPOSTransLine: Record "LSC POS Trans. Line";
        Staff: Record "LSC Staff";
        PosInfoEntry: Record "LSC POS Trans. Infocode Entry";
        POSTransaction: Record "LSC POS Transaction";
    begin
        IF Staff.GET(pPOSTransLine."Sales Staff") and (pPOSTransLine."Sales Staff" <> '') THEN
            pTransSalesEntry."FSN Sales Staff Type" := Staff."Permission Group";

        IF pPOSTransLine."Sales Staff" = '' THEN BEGIN
            PosInfoEntry.Reset();
            PosInfoEntry.SetRange("Receipt No.", POSTransC.GetReceiptNo());
            PosInfoEntry.SetRange(PosInfoEntry."Transaction Type", 0);
            if PosInfoEntry.FindLast() then begin
                IF Staff.GET(PosInfoEntry."Staff ID") THEN begin
                    pTransSalesEntry."Sales Staff" := Staff.ID;
                    pTransSalesEntry."FSN Sales Staff Type" := Staff."Permission Group";
                end;
            end;
        end;
        pTransSalesEntry."Recommended Item" := pPOSTransLine."Recommended Item";
    end;
    #endregion
    #region [Modificacion temporal]
    [EventSubscriber(ObjectType::Table, Database::"LSC POS Transaction", 'OnAfterInsertEvent', '', true, true)]
    local procedure "LSC POS Transaction_OnAfterInsertEvent"
    (
        var Rec: Record "LSC POS Transaction";
        RunTrigger: Boolean
    )
    begin
        if Rec."VAT Bus.Posting Group" = '' then
            Rec."VAT Bus.Posting Group" := 'LOCAL';

        if Rec."Gen. Bus. Posting Group" <> '' then
            Rec."Gen. Bus. Posting Group" := 'LOCALES';

        if Rec."Price Group Code" = '' then
            Rec."Price Group Code" := 'ALL';
    end;


    [EventSubscriber(ObjectType::Table, Database::"LSC POS Transaction", 'OnAfterModifyEvent', '', true, true)]
    local procedure "LSC POS Transaction_OnAfterModifyEvent"
    (
        var Rec: Record "LSC POS Transaction";
        var xRec: Record "LSC POS Transaction";
        RunTrigger: Boolean
    )
    var
        PosTransaction: Record "LSC POS Transaction";
        customer: Record Customer;
    begin
        if PosTransaction.Get(Rec."Receipt No.") then
            if customer.get(PosTransaction."Customer No.") then
                if (Rec."VAT Bus.Posting Group" = '') or (Rec."VAT Bus.Posting Group" <> customer."VAT Bus. Posting Group") then
                    Rec.Validate("VAT Bus.Posting Group", customer."VAT Bus. Posting Group");

        if Rec."VAT Bus.Posting Group" = '' then
            Rec."VAT Bus.Posting Group" := 'LOCAL';

        if Rec."Gen. Bus. Posting Group" = '' then
            Rec."Gen. Bus. Posting Group" := 'LOCALES';
    end;

    [EventSubscriber(ObjectType::Table, Database::"LSC POS Trans. Line", 'OnAfterInsertEvent', '', true, true)]
    local procedure "LSC POS Trans. Line_OnAfterInsertEvent"
    (
        var Rec: Record "LSC POS Trans. Line";
        RunTrigger: Boolean
    )
    var
        PosTransaction: Record "LSC POS Transaction";
        customer: Record Customer;
    begin
        if PosTransaction.Get(Rec."Receipt No.") then
            if customer.get(PosTransaction."Customer No.") then
                if (Rec."Vat Bus. Posting Group" = '') or (Rec."Vat Bus. Posting Group" <> customer."VAT Bus. Posting Group") then
                    Rec.Validate("Vat Bus. Posting Group", customer."VAT Bus. Posting Group");

        if Rec."Vat Bus. Posting Group" = '' then
            Rec.Validate("Vat Bus. Posting Group", 'LOCAL');

        if Rec."Gen. Bus. Posting Group" = '' then
            Rec."Gen. Bus. Posting Group" := 'LOCALES';

        if Rec."Price Group Code" = '' then
            Rec."Price Group Code" := 'ALL';
    end;


    [EventSubscriber(ObjectType::Table, Database::"LSC POS Trans. Line", 'OnAfterModifyEvent', '', true, true)]
    local procedure "LSC POS Trans. Line_OnAfterModifyEvent"
    (
        var Rec: Record "LSC POS Trans. Line";
        var xRec: Record "LSC POS Trans. Line";
        RunTrigger: Boolean
    )
    var
        PosTransaction: Record "LSC POS Transaction";
        customer: Record Customer;
    begin
        if PosTransaction.Get(Rec."Receipt No.") then
            if customer.get(PosTransaction."Customer No.") then
                if (Rec."Vat Bus. Posting Group" = '') or (Rec."Vat Bus. Posting Group" <> customer."VAT Bus. Posting Group") then
                    Rec.Validate("Vat Bus. Posting Group", customer."VAT Bus. Posting Group");

        if Rec."Vat Bus. Posting Group" = '' then
            Rec.Validate("Vat Bus. Posting Group", 'LOCAL');

        if Rec."Gen. Bus. Posting Group" = '' then
            Rec."Gen. Bus. Posting Group" := 'LOCALES';

        if Rec."Price Group Code" = '' then
            Rec."Price Group Code" := 'ALL';
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Transaction Events", 'OnAfterStartNewTransaction', '', true, true)]
    local procedure "POS Transaction Events_OnAfterStartNewTransaction"(var POSTransaction: Record "LSC POS Transaction")
    begin
        POSSESSION.SetValue('SALESTYPE', ' ');
    end;


    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Post Utility", 'OnAfterInsertTransHeader', '', true, true)]
    local procedure "LSC POS Post Utility_OnAfterInsertTransHeader"
    (
        var Transaction: Record "LSC Transaction Header";
        var POSTrans: Record "LSC POS Transaction"
    )
    var
        Customer: Record Customer;
    begin
        IF POSTrans."Entry Status" <> POSTrans."Entry Status"::Voided THEN BEGIN
            if Customer.Get(POSTrans."Customer No.") then
                if Customer."Customer Disc. Group" = '25RETORNO' then begin
                    Customer."Customer Disc. Group" := 'RETAIL';
                    Customer.Modify(true);
                end;
        END;
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
        POSMenuLine: Record "LSC POS Menu Line";
        TextLbl01: Label 'La cantidad no puede ser un valor decimal';
    begin
        if not (payload = '33') then
            exit;

        if inputValue.Contains('.') then begin
            processed := true;
            Message(TextLbl01);
        end else begin
            processed := false;
        end;
    end;
    #endregion

    //Evita procesar la transaccion con pago a $0.00.
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Transaction Events", 'OnBeforePostPOSTransaction', '', true, true)]
    local procedure "LSC POS Transaction Events_OnBeforePostPOSTransaction"(var POSTransaction: Record "LSC POS Transaction")
    var
        Mens00: label 'No se puede registrar venta con pago a $%1 en %2';
        ValidateCreditCustomer: Boolean;
        CustomerCred: Record "Customer";
        POSTranCod: Codeunit "LSC POS Transaction";
        Postransline: Record "LSC POS Trans. Line";
        parameter: Record "FSN Parameter";
        PosTransLineC: Record "LSC POS Trans. Line";
        Item: Record Item;
    begin

        if POSTransaction."Entry Status" = POSTransaction."Entry Status"::Voided then begin
            PosTransLineC.Reset();
            PosTransLineC.SetRange("Receipt No.", POSTransaction."Receipt No.");
            PosTransLineC.SetRange("Entry Status", PosTransLine."Entry Status"::" ");
            PosTransLineC.SetRange("Entry Type", PosTransLine."Entry Type"::Item);
            if PosTransLineC.Find('-') then
                repeat
                    if Item.Get(PosTransLineC.Number) then
                        if (StrPos(Item."LSC Attrib 2 Code", 'CONTROL') > 0) then
                            GetReceta(PosTransLineC."Receipt No.")
                until PosTransLineC.Next() = 0;
        end;

        if POSTransaction."Entry Status" <> POSTransaction."Entry Status"::Voided then begin
            checkSpecialCoupon(POSTransaction);
        end;

        //Message('OnBeforePostPOSTransaction');
        if parameter.Get('POS', 'CUST_BALANCE') and parameter.Activo then begin
            if POSTransaction."Entry Status" <> POSTransaction."Entry Status"::Voided then begin
                checkSpecialCoupon(POSTransaction);
                Postransline.Reset();
                Postransline.SetRange("Receipt No.", POSTransaction."Receipt No.");
                Postransline.SetRange("Entry Status", Postransline."Entry Status"::" ");
                Postransline.SetRange("Entry Type", Postransline."Entry Type"::Payment);
                Postransline.SetRange(Postransline.Number, '4');
                IF Postransline.FindFirst() THEN begin
                    CustomerCred.reset;
                    CustomerCred.get(POSTransaction."Customer No.");
                    ValidateCreditCustomer := TRUE;
                    ValidateCreditCustomer := ValidateCustomer(CustomerCred, false, false, POSTranCod.GetOutstandingBalance(), ErrorText, false);
                    if not ValidateCreditCustomer then begin
                        Error(ErrorText);
                    end;
                end;
            end;
        end;

        if POSTransaction."FSN Document Type" = POSTransaction."FSN Document Type"::"Credito Fiscal" then begin
            if POSTransaction."Entry Status" <> POSTransaction."Entry Status"::Voided then
                if POSTransaction.Payment = 0.00 then
                    Error(Mens00, POSTransaction.Payment, Format(POSTransaction."FSN Document Type"));
        end;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Print Utility", 'OnBeforePrintCustomerSlip', '', true, true)]
    local procedure "LSC POS Print Utility_OnBeforePrintCustomerSlip"
    (
        var Transaction: Record "LSC Transaction Header";
        var PrintBuffer: Record "LSC POS Print Buffer";
        var PrintBufferIndex: Integer;
        var LinesPrinted: Integer;
        var DSTR1: Text[100];
        var IsHandled: Boolean;
        var ReturnValue: Boolean
    )
    var
        Parameter: Record "FSN Parameter";
    begin
        Parameter.Reset();
        if (Parameter.Get('PRINT', 'CREDITO')) and not (Parameter.Activo) then begin
            IsHandled := true;
        end;
    end;


    //baleman
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Post Utility", 'ProcessTransactionOnAfterWriteToDB', '', true, true)]
    local procedure "LSC POS Post Utility_ProcessTransactionOnAfterWriteToDB"(POSTransaction: Record "LSC POS Transaction")
    var
        TransHeader: Record "LSC Transaction Header";
        TransSalesE, TransLine : Record "LSC Trans. Sales Entry";
        TransPayment: Record "LSC Trans. Payment Entry";
        TransInfocode: Record "LSC Trans. Infocode Entry";
        PosCardEntry: Record "LSC POS Card Entry";
        PosVoidesTLine: Record "LSC POS Voided Trans. Line";
        PosInvenEntry: Record "LSC Trans. Inventory Entry";
        TransINC: Record "LSC Trans. Inc./Exp. Entry";
        TransInv: Record "LSC Trans. Inv. Adjmt. Entry";
        TrnasHosp: Record "LSC Trans. Hospitality Entry";
        TransOrdH: Record "LSC Transaction Order Header";
        TransAdd: Record "LSC Trans. Add. Salesperson";
        TransDisc: Record "LSC Trans. Discount Entry";
        TrnasMixMath: Record "LSC Trans. Mix & Match Entry";
        TransDBene: Record "LSC Trans. Disc. Benefit Entry";
        TransCupon: Record "LSC Trans. Coupon Entry";
        TransPoint: Record "LSC Trans. Point Entry";
        VoucherEntry: Record "LSC Voucher Entries";
        _CuentaInG: Boolean;
        PosDataEntry: Record "LSC POS Data Entry";
        POSInfocode: Record "LSC POS Trans. Infocode Entry";
        POSTransLine, POSTransLineIt, PosTransLineC : Record "LSC POS Trans. Line";
        ErrorT: Text;
        DifAmount: Decimal;
        VoidedInfoCodeEntry: Record "LSC POS Voided Infoc Entry";
        InfoCodeEntry: Record "LSC Trans. Infocode Entry";
    begin

        TransHeader.Reset();
        TransHeader.SetRange("Store No.", POSTransaction."Store No.");
        TransHeader.SetRange("POS Terminal No.", POSTransaction."POS Terminal No.");
        TransHeader.SetRange("Receipt No.", POSTransaction."Receipt No.");
        if TransHeader.FindFirst() then;
        begin
            IF ((TransHeader.Rounded <> 0) and (not (POSTransaction."Entry Status" = POSTransaction."Entry Status"::Voided))) then
                Error('Transacción con error, verifique y reingresela nuevamente');
        end;
        if (POSTransaction."Entry Status" = POSTransaction."Entry Status"::Voided) then begin
            VoidedInfoCodeEntry.Reset();
            VoidedInfoCodeEntry.SetRange("Receipt No.", TransHeader."Receipt No.");
            VoidedInfoCodeEntry.SetRange(Infocode, 'ESCTRANS');
            VoidedInfoCodeEntry.SetRange("Line No.", 53);
            if VoidedInfoCodeEntry.Find('-') then
                repeat
                    InfoCodeEntry.TransferFields(VoidedInfoCodeEntry);
                    InfoCodeEntry."Transaction No." := TransHeader."Transaction No.";
                    InfoCodeEntry."POS Terminal No." := TransHeader."POS Terminal No.";
                    InfoCodeEntry.Information := 'ANULADO';
                    InfoCodeEntry.Date := TODAY();
                    InfoCodeEntry.Time := TIME();
                    if not InfoCodeEntry.Insert(true) then
                        InfoCodeEntry.Modify(true);
                until VoidedInfoCodeEntry.Next() = 0;
        end;

        if not Tipologia0(POSTransaction, ErrorT) and (not (POSTransaction."Entry Status" = POSTransaction."Entry Status"::Voided)) and (not POSTransaction."Sale Is Return Sale") then begin

            if TransHeader."FSN Document Type" in [TransHeader."FSN Document Type"::"Credito Fiscal", TransHeader."FSN Document Type"::"Nota Credito"] then begin
                TransLine.Reset();
                TransLine.SetRange("Receipt No.", POSTransaction."Receipt No.");
                TransLine.SetRange("VAT Code", 'IVA 13');
                TransLine.CalcSums("Net Amount", "VAT Amount", "Total Rounded Amt.");
                if Round(TransLine."Total Rounded Amt." / 1.13, 0.01) <> TransLine."Net Amount" then
                    DifAmount := Round(TransLine."Total Rounded Amt." / 1.13, 0.01) - TransLine."Net Amount";
                if DifAmount < -0.01 then
                    Error('Error en la transacción, reconfirme el cliente y reingrese nuevamente');
            end;

            TransINC.Reset();
            TransINC.SetRange("Store No.", TransHeader."Store No.");
            TransINC.SetRange("POS Terminal No.", TransHeader."POS Terminal No.");
            TransINC.SetRange("Transaction No.", TransHeader."Transaction No.");
            if TransINC.Find('-') then
                _CuentaInG := true;

            if not _CuentaInG then begin
                POSTransLineIt.Reset();
                POSTransLineIt.SetRange("Receipt No.", TransHeader."Receipt No.");
                POSTransLineIt.SetRange("POS Terminal No.", TransHeader."POS Terminal No.");
                POSTransLineIt.SetRange("Entry Status", POSTransLineIt."Entry Status"::" ");
                POSTransLineIt.SetRange("Entry Type", POSTransLineIt."Entry Type"::Item);
                if POSTransLineIt.Find('-') then
                    repeat
                        TransSalesE.SetRange("Transaction No.", TransHeader."Transaction No.");
                        TransSalesE.SetRange("Receipt No.", TransHeader."Receipt No.");
                        TransSalesE.SetRange("Item No.", POSTransLineIt.Number);
                        if not TransSalesE.Find('-') then
                            Error('No se encontraron lineas de venta');
                    until POSTransLineIt.Next() = 0;
            end;

            TransPayment.Reset();
            TransPayment.SetRange("Transaction No.", TransHeader."Transaction No.");
            TransPayment.SetRange("Receipt No.", TransHeader."Receipt No.");
            if not TransPayment.Find('-') then begin
                TransINC.Reset();
                TransINC.SetRange("Store No.", TransHeader."Store No.");
                TransINC.SetRange("POS Terminal No.", TransHeader."POS Terminal No.");
                TransINC.SetRange("Transaction No.", TransHeader."Transaction No.");
                if not TransINC.Find('-') then
                    Error('No se encontro lineas de pago')
            end else begin
                repeat
                    if TransPayment."Tender Type" in ['5', '20'] then begin
                        PosCardEntry.Reset();
                        PosCardEntry.SetRange("Receipt No.", TransHeader."Receipt No.");
                        PosCardEntry.SetRange("Store No.", TransHeader."Store No.");
                        if not PosCardEntry.Find('-') then
                            Error('No se encontro lineas de pago');
                    end;

                    if TransPayment."Tender Type" in ['25'] then begin
                        VoucherEntry.Reset();
                        VoucherEntry.SetRange("Receipt Number", TransHeader."Receipt No.");
                        VoucherEntry.SetRange("Store No.", TransHeader."Store No.");
                        if not VoucherEntry.Find('-') then
                            Error('No se encontro linea de voucher de GIFTCARD');

                    end;
                until TransPayment.Next() = 0;
            end;

            POSInfocode.Reset();
            POSInfocode.SetRange("Receipt No.", TransHeader."Receipt No.");
            POSInfocode.SetRange("Store No.", TransHeader."Store No.");
            POSInfocode.SetRange(Status, POSInfocode.status::" ");
            if POSInfocode.Find('-') then begin
                TransInfocode.Reset();
                TransInfocode.SetRange("Transaction No.", TransHeader."Transaction No.");
                TransInfocode.SetRange("Store No.", TransHeader."Store No.");
                TransInfocode.SetRange("Line No.", POSInfocode."Line No.");
                if not TransInfocode.FindFirst() then
                    Error('No se encontro lineas de infocodigo' + ' ' + Format(POSInfocode."Line No."));
            end;
        end;
    end;


    [EventSubscriber(ObjectType::Table, Database::"LSC Trans. Sales Entry", 'OnBeforeDeleteEvent', '', true, true)]
    local procedure "LSC Trans. Sales Entry_OnBeforeDeleteEvent"
    (
        var Rec: Record "LSC Trans. Sales Entry";
        RunTrigger: Boolean
    )
    begin
        IF not Rec.IsTemporary then
            Error('Se intento eliminar lineas de ventas');
    end;


    [EventSubscriber(ObjectType::Table, Database::"LSC Trans. Payment Entry", 'OnBeforeDeleteEvent', '', true, true)]
    local procedure "LSC Trans. Payment Entry_OnBeforeDeleteEvent"
    (
        var Rec: Record "LSC Trans. Payment Entry";
        RunTrigger: Boolean
    )
    begin
        IF not Rec.IsTemporary then
            Error('Se intento eliminar lineas de pago');
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Print Utility", 'OnBeforePrintSalesSlip', '', true, true)]
    local procedure "LSC POS Print Utility_OnBeforePrintSalesSlip"
(
    var Transaction: Record "LSC Transaction Header";
    var PrintBuffer: Record "LSC POS Print Buffer";
    var PrintBufferIndex: Integer;
    var LinesPrinted: Integer;
    var IsHandled: Boolean;
    var ReturnValue: Boolean
)
    var
        PayEntry: Record "LSC Trans. Payment Entry";
        PosStartStat: Record "LSC POS Start Status";
        PosCashDeclTmp: Record "LSC POS Cash Declaration" temporary;
        TenderType: Record "LSC Tender Type";
        ReturnText: Text;
        Text000: Label 'Para media de pago %1';
        Text001: Label 'Verifique su Caja Para media de pago %1';
        tb: Record "FSN Replen. Sales Adj. Line";

    begin

        if PosStartStat.Get(Transaction."Store No.", PosStartStat.Type::"POS Terminal", Transaction."POS Terminal No.") then begin
            Clear(PayEntry);
            clear(PosCashDeclTmp);
            PosCashDeclTmp.DeleteAll();
            Clear(ReturnText);
            PayEntry.SetCurrentKey("Tender Decl. ID", "Tender Type", "Currency Code");
            PayEntry.SetRange("Tender Decl. ID", PosStartStat."Next Tender Decl. ID");
            PayEntry.SetRange("Store No.", Transaction."Store No.");
            PayEntry.SetRange("POS Terminal No.", Transaction."POS Terminal No.");
            if PayEntry.FindFirst then
                repeat
                    if PosCashDeclTmp.Get('', PayEntry."Tender Type", PayEntry."Currency Code", PayEntry."Card No.") then begin
                        PosCashDeclTmp."Trans. Amount" := PosCashDeclTmp."Trans. Amount" + PayEntry."Amount in Currency";
                        PosCashDeclTmp.Modify;
                    end
                    else begin
                        if TenderType.Get(PayEntry."Store No.", PayEntry."Tender Type") then
                            if TenderType."POS Pickup Warning Amount" <> 0 then begin
                                Clear(PosCashDeclTmp);
                                PosCashDeclTmp."Tender Type" := PayEntry."Tender Type";
                                PosCashDeclTmp."Currency Code" := PayEntry."Currency Code";
                                PosCashDeclTmp."Card No." := PayEntry."Card No.";
                                PosCashDeclTmp."Trans. Amount" := PayEntry."Amount in Currency";
                                PosCashDeclTmp.Insert;
                            end;
                    end;
                until PayEntry.Next() = 0;

            TenderType.Reset();
            TenderType.SetCurrentKey("Store No.", Code);
            TenderType.SetRange("Store No.", Transaction."Store No.");
            TenderType.Setfilter("POS Pickup Warning Amount", '<>%1', 0);
            if TenderType.Find('-') then
                repeat
                    PosCashDeclTmp.Reset();
                    if PosCashDeclTmp.Get('', TenderType.Code, '') then
                        if PosCashDeclTmp."Trans. Amount" > TenderType."POS Pickup Warning Amount" then begin
                            if TenderType."POS Pickup Warning Text" <> '' then begin
                                if ReturnText <> '' then
                                    ReturnText := ReturnText + ',' + TenderType.Description
                                else
                                    ReturnText := TenderType."POS Pickup Warning Text" + ' ' + StrSubstNo(Text000, TenderType.Description);
                            end else begin
                                if ReturnText <> '' then
                                    ReturnText := ReturnText + ',' + TenderType.Description
                                else
                                    ReturnText := StrSubstNo(Text001, TenderType.Description);
                            end;
                        end;
                until TenderType.Next() = 0;

            if ReturnText <> '' then
                Message(ReturnText);
        end;
    end;

    [EventSubscriber(ObjectType::Table, Database::"FSN Replen. Sales Adj. Line", 'OnBeforeInsertEvent', '', true, true)]
    local procedure "FSN Replen. Sales Adj. Line_OnBeforeInsertEvent"
(
    var Rec: Record "FSN Replen. Sales Adj. Line";
    RunTrigger: Boolean
)
    var
        lItem: Record "Item";
        IUOM: Record "Item Unit of Measure";
        ValQuantity: Integer;
        LongText: Integer;
        MText: Integer;
        LongText2: Integer;
        t: Text;
        valtext: Text;
    begin
        if Rec.Quantity > 3 then begin
            ValQuantity := 0;
            if lItem.get(Rec."Item No.") then begin
                if IUOM.Get(Rec."Item No.", Rec."Unit of Measure") then
                    if (Rec."Unit of Measure" = lItem."Purch. Unit of Measure") and (IUOM."Qty. per Unit of Measure" > 1) then begin
                        Rec.Quantity := 3;
                    end else begin
                        ValQuantity := IUOM."Qty. per Unit of Measure" * 3;
                        if Rec.Quantity > ValQuantity then
                            Rec.Quantity := ValQuantity;
                    end;
            end;
        end;
    end;

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
        RequestID := 'FSNCC';
        ProcessedCC := false;
        FSNUtility.InvokeGlobalChannel(XMLRequest, XMLResponse, RequestID, PosMenuLineTemp, ProcessedCC, MsgResult);
        If not ProcessedCC then begin
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
    //JH16092024 Actualizar Linea de Cliente POS
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Transaction Events", 'OnAfterTotalExecuted', '', true, true)]
    local procedure "LSC POS Transaction Events_OnAfterTotalExecuted"
    (
     var POSTransaction: Record "LSC POS Transaction"
    )
    var
        pREC: Record "LSC POS Transaction";
        POSTrans: Codeunit "LSC POS Transaction";
        infocode: Record "LSC POS Trans. Infocode Entry";
        transLine, transLinecal : Record "LSC POS Trans. Line";
        session: Codeunit "LSC POS Session";
        Customer: Record Customer;
        menuLine: Record "LSC POS Menu Line";
        XMLRequest: Text;
        XMLResponse: Text;
        RequestID: Text[50];
        PosMenuLineTemp: Record "LSC POS Menu Line" temporary;
        Processed: Boolean;
        MsgResult: text;
        FSNUtility: Codeunit "FSN Utility";
    begin
        infocode.Reset();
        infocode.SetRange("Store No.", POSTransaction."Store No.");
        infocode.SetRange("Receipt No.", POSTransaction."Receipt No.");
        infocode.SetRange("POS Terminal No.", POSTransaction."POS Terminal No.");
        infocode.SetRange("Transaction Type", 0);
        infocode.SetRange("Line No.", 48);
        infocode.SetRange("Infocode", 'TEXT');
        if infocode.FindFirst() then begin
            if infocode.Information <> '' then begin
                transLine.Reset();
                transLine.SetRange("Receipt No.", POSTrans.GetReceiptNo());
                transLine."Store No." := session.StoreNo();
                transLine."POS Terminal No." := session.TerminalNo();
                transLine.SetRange("Entry Type", transLine."Entry Type"::FreeText);
                transLine.SetRange("Text Type", transLine."Text Type"::"Cust. Text");
                if transLine.FindFirst then begin
                    transLine.Description := 'Clie: ' + infocode.Information;
                    transLine.Modify(true);
                end;
            end;
        end;

        Customer.Get(POSTransaction."Customer No.");
        if (Customer."Customer Disc. Group" = 'LNB') OR (EvaluateIsNeedReAddCust(POSTransaction)) OR (CalcCuponTotal(POSTransaction)) then begin
            transLinecal.Reset();
            transLinecal.SetRange("Receipt No.", POSTrans.GetReceiptNo());
            transLinecal.SetRange("Entry Type", transLinecal."Entry Type"::Item);
            transLinecal.SetRange("Entry Status", transLinecal."Entry Status"::" ");
            if transLinecal.FindSet() then begin
                repeat
                    transLinecal.CalcPrices();
                    transLinecal.Modify(true);
                until transLinecal.Next() = 0;
                POSTrans.CalcTotals();
            end;
        end;
        RequestID := 'FSNCC';
        Processed := false;
        FSNUtility.InvokeGlobalChannel(XMLRequest, XMLResponse, RequestID, PosMenuLineTemp, Processed, MsgResult);
        If Processed then begin
            transLine.Reset();
            transLine.SetRange(transLine."Receipt No.", POSTransaction."Receipt No.");
            transLine.SetRange(transLine."Entry Type", transLine."Entry Type"::Item);
            transLine.SetRange(transLine."Entry Status", transLine."Entry Status"::" ");
            if transLine.Find('-') then
                repeat
                    ValueItemOfMeasureDescription(transLine);
                until transLine.Next() = 0;
        end;
    end;
    //JH16092024

    local procedure CalcCuponTotal(POSTransaction: Record "LSC POS Transaction"): Boolean
    var
        PosTransLine: Record "LSC POS Trans. Line";
        PeriodicDisc: Record "LSC Periodic Discount";
    begin
        PosTransLine.Reset();
        PosTransLine.SetRange("Receipt No.", POSTransaction."Receipt No.");
        PosTransLine.SetRange("Entry Type", PosTransLine."Entry Type"::Coupon);
        PosTransLine.SetRange("Entry Status", PosTransLine."Entry Status"::" ");
        if PosTransLine.FindSet() then begin
            repeat
                PeriodicDisc.Reset();
                PeriodicDisc.SetRange(Type, PeriodicDisc.Type::"Total Discount");
                PeriodicDisc.SetRange(Status, PeriodicDisc.Status::Enabled);
                PeriodicDisc.SetRange("Coupon Code", PosTransLine."Coupon Code");
                if PeriodicDisc.FindSet() then
                    exit(true);
            until PosTransLine.Next() = 0;
        end;
    end;

    procedure ValueItemOfMeasureDescription(var POSTransLineRec: Record "LSC POS Trans. Line")
    var
        itemUnitOfMeasure: Record "Item Unit of Measure";
        ItemRec: Record "Item";
        ProductExt: codeunit "LSC Product Ext.";
        i: Integer;
    begin
        i := 0;
        itemUnitOfMeasure.Reset();
        itemUnitOfMeasure.SetRange("Item No.", POSTransLineRec.Number);
        if itemUnitOfMeasure.Find('-') then
            if (itemUnitOfMeasure.Count > 1) then begin
                itemUnitOfMeasure.Reset;
                itemUnitOfMeasure.SetRange("Item No.", POSTransLineRec.Number);
                ProductExt.FilterOnValidUOMPricesInStore(itemUnitOfMeasure, POSTransLineRec.Number, POSTransLineRec."Store No.", '');
                if (itemUnitOfMeasure.Count >= 1) then begin
                    if ItemRec.get(POSTransLineRec.Number) then
                        if (POSTransLineRec."Unit of Measure" <> '') and (ItemRec."Base Unit of Measure" = POSTransLineRec."Unit of Measure") then begin
                            if STRPOS(POSTransLineRec.Description, '#####') = 0 then begin
                                POSTransLineRec.Description += ' ';
                                POSTransLineRec.Mark(true);
                                WHILE i < 5 DO BEGIN
                                    POSTransLineRec.Description += '#';
                                    i += 1;
                                END;
                                POSTransLineRec.Modify();
                            end;
                        end;
                end;
            end;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Print Utility", 'OnBeforePrintSuspendSlip', '', true, true)]
    local procedure "LSC POS Print Utility_OnBeforePrintSuspendSlip"
    (
        var DSTR1: Text[100];
        var IsHandled: Boolean;
        var ReturnValue: Boolean;
        var POSTrans: Record "LSC POS Transaction";
        var tmpPosTransLines: Record "LSC POS Trans. Line"
    )
    var
        POSInfo: Record "LSC POS Trans. Infocode Entry";
    begin
        if POSInfo.Get(POSTrans."Receipt No.", POSInfo."Transaction Type"::Header, 53, 'ESCTRANS', 0) then begin
            IsHandled := true;
            ReturnValue := true;
        end;
    end;


    //PROCESS GIFTCAR CC

    //210725
    //se invoca en el total y se valida si existe el infocodigo de recarga, si no existe solicita el numero de giftcard
    procedure ValGiftCardProcess(POSTransaction: Record "LSC POS Transaction"): Boolean
    var
        myInt: Integer;
        Result: Action;
        caption: Label 'No GiftCard:';
        TransLine: Record "LSC POS Trans. Line";
        ErrorText: Text;
        XMLRequest: Text;
        XMLResponse: Text;
        RequestID: Text[50];
        PosMenuLineTemp: Record "LSC POS Menu Line" temporary;
        Processed: Boolean;
        MsgResult: text;
        FSNUtility: Codeunit "FSN Utility";
    begin

        IF NOT POSTransaction."Sale Is Return Sale" THEN BEGIN
            RequestID := 'FSNCC';
            Processed := false;
            FSNUtility.InvokeGlobalChannel(XMLRequest, XMLResponse, RequestID, PosMenuLineTemp, Processed, MsgResult);
            if not Processed then begin
                TransLine.Reset();
                TransLine.SetRange(TransLine."Store No.", POSTransaction."Store No.");
                TransLine.SetRange(TransLine."POS Terminal No.", POSTransaction."POS Terminal No.");
                TransLine.SetRange(TransLine."Receipt No.", POSTransaction."Receipt No.");
                TransLine.SetRange(TransLine."Entry Type", TransLine."Entry Type"::Item);
                TransLine.SetRange(TransLine."Entry Status", TransLine."Entry Status"::" ");
                if TransLine.Find('-') then
                    repeat
                        if ValExistInfoEntry(TransLine) then begin
                            POSSession.SetValue('#GIFTPROCESS', 'TRUE');
                            POSSession.SetValue('#GIFTLINE', Format(TransLine."Line No."));
                            POSGUI.OpenAlphabeticKeyboard(CopyStr(StrSubstNo(caption), 1, 50), '', Result, true);
                            exit(true);
                        END;
                    until TransLine.Next() = 0;
                exit(false);
            end;
        end;
        exit(false);
    end;

    //se valida si existe el infocodigo de recarga de giftcard
    procedure ValExistInfoEntry(PosTransLine: Record "LSC POS Trans. Line"): Boolean
    var
        POSTransInfocEntry: Record "LSC POS Trans. Infocode Entry";
        TableSpeInfocode: Record "LSC Table Specific Infocode";
        Infocode: Record "LSC Infocode";
    begin
        TableSpeInfocode.SetCurrentKey("Table ID", Value, "Infocode Code");
        TableSpeInfocode.SetRange("Table ID", Database::Item);
        TableSpeInfocode.SetRange(Value, PosTransLine.Number);
        if TableSpeInfocode.FindFirst() then
            if Infocode.Get(TableSpeInfocode."Infocode Code") and (Infocode.Type = Infocode.Type::"Create Data Entry") then begin
                POSTransInfocEntry.SetCurrentKey("Receipt No.", "Transaction Type", "Line No.", Infocode);
                POSTransInfocEntry.SetRange(POSTransInfocEntry."Receipt No.", PosTransLine."Receipt No.");
                POSTransInfocEntry.SetRange(POSTransInfocEntry."Transaction Type", POSTransInfocEntry."Transaction Type"::"Sales Entry");
                POSTransInfocEntry.SetRange(POSTransInfocEntry."Line No.", PosTransLine."Line No.");
                POSTransInfocEntry.SetRange(POSTransInfocEntry.Infocode, Infocode.Code);
                if not POSTransInfocEntry.FindFirst() then
                    exit(true);
            end;
        exit(false);
    end;

    //Se procesa la giftcard CC
    procedure ProcessGiftcardCC(inputValue: text)
    var
        myInt: Integer;
        TransLine: Record "LSC POS Trans. Line";
        POSTransaction: Codeunit "LSC POS Transaction";
        infocoRec: Record "LSC Infocode";
        POSInfocodeEntryC: Codeunit "LSC POS Infocode Utility";
        ProdDescription: Label '%1 %2';
        Canceled: Boolean;
        TSError: Boolean;
        ValueItemDescription: Text;
        EntryLineNo: Integer;
        InfoSubCode: Record "LSC Information Subcode";
        TableSpeInfocode: Record "LSC Table Specific Infocode";
        Line: Integer;
    begin
        Canceled := false;
        TSError := false;
        EntryLineNo := 0;
        Line := 0;
        if Evaluate(Line, POSSession.GetValue('#GIFTLINE')) then;
        if Line <> 0 then begin
            TransLine.Reset();
            TransLine.SetRange(TransLine."Receipt No.", POSTransaction.GetReceiptNo());
            TransLine.SetRange(TransLine."Entry Type", TransLine."Entry Type"::Item);
            TransLine.SetRange(TransLine."Entry Status", TransLine."Entry Status"::" ");
            TransLine.SetRange(TransLine."Line No.", Line);
            if TransLine.FindFirst() then begin
                TableSpeInfocode.SetCurrentKey("Table ID", Value, "Infocode Code");
                TableSpeInfocode.SetRange("Table ID", Database::Item);
                TableSpeInfocode.SetRange(Value, TransLine.Number);
                if TableSpeInfocode.FindFirst() then begin
                    if infocoRec.get(TableSpeInfocode."Infocode Code") then begin
                        POSInfocodeEntryC.IsInputOk(infocoRec, inputValue, ValueItemDescription, TransLine, Canceled, false, false, TSError, 0, '', '', false, 0, false, EntryLineNo);
                        FreeTextGiftcard(inputValue);
                    end;
                end;
            end;
        end;
    end;

    procedure FreeTextGiftcard(inputValue: text)
    var
        myInt: Integer;
        xPOStemp: Record "LSC POS Trans. Line";
        posTransaB: record "LSC pos Transaction";
        POSTransaction: Codeunit "LSC pos Transaction";
    begin
        IF posTransaB.GET(POSTransaction.GetReceiptNo()) THEN BEGIN
            xPOStemp.INIT();
            xPOStemp."Store No." := posTransaB."Store No.";
            xPOStemp."POS Terminal No." := posTransaB."POS Terminal No.";
            xPOStemp."Receipt No." := posTransaB."Receipt No.";
            xPOStemp."Entry Type" := xPOStemp."Entry Type"::FreeText;
            xPOStemp."Line No." := LastPosTransLine(posTransaB) + 10000;
            xPOStemp."Entry Status" := 0;
            xPOStemp."Text Type" := xPOStemp."Text Type"::"Freetext Input";
            xPOStemp.Description := COPYSTR('GIFTCARD No  : ' + inputValue, 1, 50);
            if not xPOStemp.INSERT(TRUE) then
                xPOStemp.Modify(TRUE);
        END;
    end;

    procedure RunGiftcardBalance()
    var
        Result: Action;
        caption: Label 'No GiftCard:';
    begin
        POSSession.SetValue('#GIFTBALANCEPROCESS', 'TRUE');
        POSGUI.OpenAlphabeticKeyboard(CopyStr(StrSubstNo(caption), 1, 50), '', Result, true);
    end;

    local procedure ConsultationGiftcard(EntryCode: Code[20]; var balance: Decimal; var ExpiringDate: Text; var EntryType: Code[30]): Boolean
    var
        con: Text;
        sqlConnection: DotNet SqlConnection;
        sqlCommand: DotNet SqlCommand;
        sqlDataReader: DotNet SqlDataReader;
        distrLocation: Record "LSC Distribution Location";
        ReailUser: Record "LSC Retail Setup";
        ResultMessage: Text;
        CodeResult: Integer;
        lTextConn: Label 'Data Source=%1;Initial Catalog=%2;Integrated Security=false;User ID=%3;Password=%4;';
        ExpDateTxt: text;
        DayInt: Integer;
        MonthInt: Integer;
        YearInt: Integer;

    begin
        ReailUser.Get();
        if distrLocation.Get('HO') then;

        con := StrSubstNo(lTextConn,
            distrLocation."DB Server Name",
            'BCENTRAL',
            distrLocation."User ID",
            distrLocation.Password);

        sqlConnection := sqlConnection.SqlConnection(con);
        sqlConnection.Open();

        sqlCommand := sqlConnection.CreateCommand();
        sqlCommand.CommandText := 'sp_GiftcardBalance';
        sqlCommand.CommandType := 4; // Tipo StoredProcedure

        sqlCommand.Parameters.AddWithValue('@EntryCode', EntryCode);

        // Ejecutar SP
        sqlDataReader := sqlCommand.ExecuteReader();
        IF sqlDataReader.Read() THEN BEGIN
            // Mapeo de columnas según SELECT del SP
            EntryCode := Format(sqlDataReader.GetValue(0));
            balance := sqlDataReader.GetDecimal(1);
            ExpiringDate := sqlDataReader.GetValue(2);
            EntryType := Format(sqlDataReader.GetValue(3));
        END;
        // Cerrar conexiones
        sqlDataReader.Close();
        sqlConnection.Close();
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Transaction Events", 'OnBeforeProcessBarcode', '', true, true)]
    local procedure "LSC POS Transaction Events_OnBeforeProcessBarcode"
    (
        var POSTransaction: Record "LSC POS Transaction";
        var POSTransLine: Record "LSC POS Trans. Line";
        var CurrInput: Text;
        var IsHandled: Boolean
    )
    VAR
        POSSESSION: Codeunit "LSC POS Session";
        InputNo: Integer;
        PostTrans: Codeunit "LSC POS Transaction";
    begin
        IF POSTransLine."Entry Type" IN [POSTransLine."Entry Type"::Item, POSTransLine."Entry Type"::IncomeExpense] then begin
            if POSTransLine.Number IN ['A3582', '12'] then begin
                if (CopyStr(UpperCase(CurrInput), 1, 2) <> 'GC') and
                    (CopyStr(UpperCase(CurrInput), 1, 2) <> 'DS') then begin
                    CurrInput := RemoveSpecialCharactersGiftCard(CurrInput);

                    if StrLen(CurrInput) < 5 then
                        Error('La GiftCard debe tener como minimo 5 caracteres. Valor actual: %1', CurrInput);

                    if Evaluate(InputNo, CurrInput) and
                      ((CopyStr(CurrInput, 1, 3) = '214') or (CopyStr(CurrInput, 1, 3) = '215')) then
                        CurrInput := 'GC' + CurrInput;
                end;
            end;
        end;
    end;

    local procedure RemoveSpecialCharactersGiftCard(input: Text): Text
    var
        i: Integer;
        output: Text;
    begin
        output := '';
        for i := 1 to StrLen(input) do begin
            if (input[i] in ['A' .. 'Z', 'a' .. 'z', '0' .. '9']) then
                output := output + input[i];
        end;
        exit(output);
    end;

}
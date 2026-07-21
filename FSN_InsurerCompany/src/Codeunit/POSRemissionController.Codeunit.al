codeunit 50024 "FSN POS Remission Controller"
{
    //SingleInstance = true;
    TableNo = 99008906;

    trigger OnRun()
    begin
        GlobalRec := Rec;
        case Command of
            'REMISSION_CO':
                RemissionCoPressed(Rec);
            /*'REMISSION_CO_SELECT',
            'REMISSION_INV_SELECT':
                RemissionSelection();*/
            'REMISSION_INV':
                RemissionInvoicePressed(Rec);
            'TESTREMISSION':
                begin
                    document := document.XmlDocument();
                    document.Load('C:\Temp\FSN_SEND_REMISSION_TEST2.xml');
                    pxmlRequest := document.OuterXml();
                    WS.SendRemission(pxmlRequest, pxmlResponse);
                END;
        end
    end;

    var
        pxmlRequest: Text;
        pxmlResponse: Text;
        WS: Codeunit "FSN WS XML Remss. Integration";
        document: DotNet XmlDocument;
        POSTransaction_g: Record "LSC POS Transaction";
        POSTransLine_g: Record "LSC POS Trans. Line";
        POSSESSION: Codeunit "LSC POS Session";
        POSGUI: Codeunit "LSC POS GUI";
        GlobalRec: Record "LSC POS Menu Line";
        POSTransaction: Codeunit "LSC POS Transaction";
        POSLINE: Codeunit "LSC POS Trans. Lines";
        EPOSControlInterface: codeunit "LSC POS Control Interface";
        Parametrosfsn: Record "FSN Parameter";

    procedure RemissionCoPressed(pPosMenuLine: Record "LSC POS Menu Line")
    var
        lRemissionHeader: Record "FSN Remission Header";
        lRemissionHeaderTmp: Record "FSN Remission Header" temporary;
        lCompany: Record "FSN Company Insurer";
        lCompany2: Record "FSN Company Insurer";
        RemissionRef: RecordRef;
        lText001: Label 'Company %1 dont require Coinsurance.';
        lText002: Label 'Dont have records. Company %1';
        lText003: Label 'Transaction already lines Items or Income/Expense';
        lPOSTransLine: Record "LSC POS Trans. Line";
        SelectRemissionTemp: Page "FSN Select Remission Tempory";
    begin
        //RemissionCoPressed  
        lPOSTransLine.Reset();
        lPOSTransLine.SetRange(lPOSTransLine."Receipt No.", GlobalRec."Current-RECEIPT");
        lPOSTransLine.SetRange(lPOSTransLine."Entry Status", 0);
        lPOSTransLine.SetFilter(lPOSTransLine."Entry Type", '%1|%2', lPOSTransLine."Entry Type"::Item, lPOSTransLine."Entry Type"::IncomeExpense);
        if lPOSTransLine.find('-') then begin
            POSGUI.PosMessage(StrSubstNo(lText003));
            exit;
        end;

        lCompany.GET(pPosMenuLine.Parameter);
        IF lCompany."Invoiced In Status Released" THEN BEGIN
            POSGUI.PosMessage(STRSUBSTNO(lText001, lCompany.Description));
            EXIT;
        END;

        lRemissionHeaderTmp.RESET;
        lRemissionHeaderTmp.DELETEALL;

        lRemissionHeader.RESET;
        lRemissionHeader.SETCURRENTKEY("Company No.", "Customer No.", Status);
        lRemissionHeader.SETRANGE(lRemissionHeader."Customer No.", lCompany."Customer No.");
        IF lCompany."Bill Alone" THEN
            lRemissionHeader.SETRANGE(lRemissionHeader."Company No.", lCompany."No.");

        lRemissionHeader.SETRANGE(lRemissionHeader.Status, lRemissionHeader.Status::Released);
        IF NOT lRemissionHeader.FINDFIRST THEN
            EXIT
        ELSE
            REPEAT
                SelectRemissionTemp.SETGLOBALVALUE(lRemissionHeader, lCompany."Lookup Coinsurance");
            /*lRemissionHeaderTmp.INIT();
            lRemissionHeaderTmp := lRemissionHeader;
            IF lRemissionHeaderTmp.INSERT THEN;*/
            UNTIL lRemissionHeader.NEXT = 0;

        Commit();
        SelectRemissionTemp.RunModal();
        //RemissionRef.GETTABLE(lRemissionHeaderTmp);
        //POSTransaction.LookUpEx(true, lCompany."Lookup Coinsurance", '', RemissionRef);
    end;

    procedure InsertRemissionCo(LookupKeyValue: Code[20]; COReceipt: Code[20])
    var
        lRemissionHeader: Record "FSN Remission Header";
        lRemissionLine: Record "FSN Remission Line";
        lNextPosLine: Record "LSC POS Trans. Line";
        NewLine: Record "LSC POS Trans. Line";
        POSTrans: record "LSC POS Transaction";
        lCompanyInsurer: Record "FSN Company Insurer";
        FSNInsureLicks: Record "FSN Insured Links";
        lText001: Label '%1 %2';
        _Price: Decimal;
        _NextLine: Integer;
        Item: Record Item;
    begin
        //InsertRemissionCo 
        POSTrans.Get(COReceipt);
        lRemissionHeader.GET(lRemissionHeader."Document Type"::Remission, LookupKeyValue);
        lRemissionHeader.CALCFIELDS(lRemissionHeader."Deductible Amount", lRemissionHeader.Comission, lRemissionHeader."Coinsurance Value");

        lCompanyInsurer.Get(lRemissionHeader."Company No.");

        lNextPosLine.RESET;
        lNextPosLine.SETCURRENTKEY("Receipt No.", "Line No.");
        lNextPosLine.SETRANGE(lNextPosLine."Receipt No.", COReceipt);
        IF lNextPosLine.FINDLAST THEN
            _NextLine := lNextPosLine."Line No." + 10000
        ELSE
            _NextLine := 10000;

        lRemissionLine.RESET;
        lRemissionLine.SETCURRENTKEY("Document Type", "Document No.", "Line No.");
        lRemissionLine.SETRANGE(lRemissionLine."Document Type", lRemissionHeader."Document Type");
        lRemissionLine.SETRANGE(lRemissionLine."Document No.", lRemissionHeader."No.");
        IF lRemissionLine.FINDFIRST THEN
            REPEAT
                IF lRemissionLine.Type = lRemissionLine.Type::Item THEN begin
                    Item.Reset();
                    if Item.Get(lRemissionLine."No.") then
                        if (StrPos(Item."LSC Attrib 2 Code", 'CONTROL') > 0) then
                            if not RecetaReg(POSTrans) then
                                if GetRecetas(lRemissionHeader."No.", POSTrans) then
                                    _NextLine += 10000;
                end;

                IF lRemissionLine.Type <> lRemissionLine.Type::Item THEN BEGIN
                    //POSTransaction.InitNewLine;
                    NewLine.Init();
                    NewLine."Store No." := POSTrans."Store No.";
                    NewLine."POS Terminal No." := POSTrans."POS Terminal No.";
                    NewLine."Receipt No." := POSTrans."Receipt No.";

                    NewLine."Line No." := _NextLine;
                    NewLine."Entry Type" := NewLine."Entry Type"::Item;
                    NewLine."Barcode No." := lRemissionLine.Barcode;
                    NewLine."Entry Status" := 0;
                    NewLine."Text Type" := 0;
                    NewLine.VALIDATE("Unit of Measure", lRemissionLine."Unit of Measure");
                    NewLine.VALIDATE(Number, lRemissionLine."No.");
                    NewLine.VALIDATE(Quantity, lRemissionLine.Quantity);
                    NewLine.VALIDATE("Sales Staff", lRemissionHeader."Sales Staff");
                    NewLine."System-Block Manual Discount" := TRUE;
                    NewLine."System-Exclude from Offers" := TRUE;
                    NewLine."System-Unchangable Price" := TRUE;
                    NewLine."System-Unchangable Discounts" := TRUE;
                    NewLine."System-Unchangable Offer" := TRUE;
                    NewLine."System-Block Promotion Price" := TRUE;
                    NewLine."System-Block Periodic Discount" := TRUE;
                    NewLine."FSN Remission No." := lRemissionHeader."No.";
                    NewLine."Lot No." := lRemissionLine.Lot;
                    NewLine."Expiration Date" := lRemissionLine."Expiration Date";
                    NewLine.Description := lRemissionLine.Description;
                    _Price := lRemissionLine."Amount Including VAT" / lRemissionLine.Quantity;
                    NewLine.VALIDATE(Price, _Price);
                    NewLine.CalcPrices();
                    //NewLine.INSERT(TRUE);
                    NewLine.InsertLine();
                    lRemissionLine."Receipt No. Coinsurance" := POSTrans."Receipt No.";
                    lRemissionLine."POS Terminal No. Coinsurance" := POSTrans."POS Terminal No.";
                    lRemissionLine.MODIFY(TRUE);
                    _NextLine += 10000;
                END;
            UNTIL lRemissionLine.NEXT = 0;

        lRemissionHeader.Status := lRemissionHeader.Status::"Coinsurance Invoiced";
        lRemissionHeader."Receipt No. Coinsurance" := POSTrans."Receipt No.";
        lRemissionHeader."POS Terminal No. Coinsurance" := POSTrans."POS Terminal No.";
        lRemissionHeader.ModifyTrigger;
        lRemissionHeader.MODIFY;

        //SetCustomer(lRemissionHeader);

        TextPressedInLine(STRSUBSTNO(lText001, lCompanyInsurer."Coinsurance Text Add", lRemissionHeader."External Document No."), _NextLine, COReceipt);
        FSNInsureLicks.reset;
        if FSNInsureLicks.Get(lRemissionHeader."Company No.", lRemissionHeader."Insured Card No.") then
            SetCustomer(lRemissionHeader, FSNInsureLicks."Customer No.");
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
                exit(true);
            end else
                exit(false);
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

    procedure RemissionInvoicePressed(pPosMenuLine: Record "LSC POS Menu Line")
    var
        lRemissionHeader: Record "FSN Remission Header";
        lRemissionHeaderTmp: Record "FSN Remission Header" temporary;
        lCompany: Record "FSN Company Insurer";
        lCompany2: Record "FSN Company Insurer";
        RemissionRef: RecordRef;
        lText002: Label 'Dont have records. Company %1';
        lText003: Label 'Transaction already lines Items or Income/Expense';
        lPOSTransLine: Record "LSC POS Trans. Line";
        SelectRemissionTemp: Page "FSN Select Remission Tempory";
    begin
        begin
            //RemissionInvoicePressed 
            lPOSTransLine.Reset();
            lPOSTransLine.SetRange(lPOSTransLine."Receipt No.", GlobalRec."Current-RECEIPT");
            lPOSTransLine.SetRange(lPOSTransLine."Entry Status", 0);
            lPOSTransLine.SetFilter(lPOSTransLine."Entry Type", '%1|%2', lPOSTransLine."Entry Type"::Item, lPOSTransLine."Entry Type"::IncomeExpense);
            if lPOSTransLine.find('-') then begin
                POSGUI.PosMessage(StrSubstNo(lText003));
                exit;
            end;

            lCompany.GET(pPosMenuLine.Parameter);

            lRemissionHeader.RESET;
            lRemissionHeader.SETCURRENTKEY("Company No.", "Customer No.", Status);
            lRemissionHeader.SETRANGE(lRemissionHeader."Customer No.", lCompany."Customer No.");
            IF lCompany."Bill Alone" THEN
                lRemissionHeader.SETRANGE(lRemissionHeader."Company No.", lCompany."No.");

            IF lCompany."Invoiced In Status Released" THEN
                lRemissionHeader.SETRANGE(lRemissionHeader.Status, lRemissionHeader.Status::Released)
            ELSE
                lRemissionHeader.SETRANGE(lRemissionHeader.Status, lRemissionHeader.Status::"Coinsurance Invoiced");
            IF NOT lRemissionHeader.FINDFIRST THEN
                EXIT
            ELSE BEGIN
                REPEAT
                    lCompany2.GET(lRemissionHeader."Company No.");
                    IF lCompany2."Bill Alone" AND (lCompany2."No." <> lCompany."No.") THEN BEGIN
                    END ELSE BEGIN
                        SelectRemissionTemp.SETGLOBALVALUE(lRemissionHeader, lCompany."Lookup Final Invoice");
                        /*lRemissionHeaderTmp.INIT();
                        lRemissionHeaderTmp := lRemissionHeader;
                        IF lRemissionHeaderTmp.INSERT() THEN;*/
                    END;
                UNTIL lRemissionHeader.NEXT = 0;
            END;
            Commit();
            SelectRemissionTemp.RunModal();
            //RemissionRef.GETTABLE(lRemissionHeaderTmp);
            //POSTransaction.LookUpEx(true, lCompany."Lookup Final Invoice", '', RemissionRef);

        end;
    end;

    procedure InsertRemissionInvoice(LookupKeyValue: Code[20]; INReceipt: Code[20])
    var
        lRemissionHeader: Record "FSN Remission Header";
        lRemissionLine: Record "FSN Remission Line";
        lNextPosLine: Record "LSC POS Trans. Line";
        NewLine: Record "LSC POS Trans. Line";
        POSTrans: Record "LSC POS Transaction";
        lCompanyInsurer: Record "FSN Company Insurer";
        _No: Code[20];
        _Price: Decimal;
        _NextLine: Integer;
        lText001: Label '%1 %2';
        CustomerCompany: Record Customer;
        lInsuredLinks: Record "FSN Insured Links";
        lCompanyInsurer2: Record "FSN Company Insurer";
        Item: Record Item;
    begin
        //InsertRemissionInvoice 
        lRemissionHeader.GET(lRemissionHeader."Document Type"::Remission, LookupKeyValue);
        POSTrans.get(INReceipt);

        SetCustomer(lRemissionHeader, '');

        lNextPosLine.RESET;
        lNextPosLine.SETCURRENTKEY("Receipt No.", "Line No.");
        lNextPosLine.SETRANGE(lNextPosLine."Receipt No.", INReceipt);
        IF lNextPosLine.FINDLAST THEN
            _NextLine := lNextPosLine."Line No." + 10000
        ELSE
            _NextLine := 10000;

        lRemissionLine.RESET;
        lRemissionLine.SETCURRENTKEY("Document Type", "Document No.", "Line No.");
        lRemissionLine.SETRANGE(lRemissionLine."Document Type", lRemissionHeader."Document Type");
        lRemissionLine.SETRANGE(lRemissionLine."Document No.", lRemissionHeader."No.");
        IF lRemissionLine.FINDFIRST THEN
            REPEAT

                IF lRemissionLine.Type = lRemissionLine.Type::Item THEN begin
                    Item.Reset();
                    if Item.Get(lRemissionLine."No.") then
                        if (StrPos(Item."LSC Attrib 2 Code", 'CONTROL') > 0) then
                            if not RecetaReg(POSTrans) then
                                if GetRecetas(lRemissionHeader."No.", POSTrans) then
                                    _NextLine += 10000;
                end;

                IF lRemissionLine.Type <> lRemissionLine.Type::Comission THEN BEGIN
                    //InitNewLine;
                    NewLine.Init();
                    NewLine."Store No." := POSTrans."Store No.";
                    NewLine."POS Terminal No." := POSTrans."POS Terminal No.";
                    NewLine."Receipt No." := POSTrans."Receipt No.";

                    NewLine."Line No." := _NextLine;
                    NewLine."Entry Type" := NewLine."Entry Type"::Item;
                    NewLine."Barcode No." := lRemissionLine.Barcode;
                    NewLine."Entry Status" := 0;
                    NewLine."Text Type" := 0;
                    NewLine.VALIDATE("Unit of Measure", lRemissionLine."Unit of Measure");
                    NewLine.VALIDATE(Number, lRemissionLine."No.");
                    NewLine.VALIDATE(Quantity, lRemissionLine.Quantity);
                    NewLine.VALIDATE("Sales Staff", lRemissionHeader."Sales Staff");
                    NewLine."System-Block Manual Discount" := TRUE;
                    NewLine."System-Exclude from Offers" := TRUE;
                    NewLine."System-Unchangable Price" := TRUE;
                    NewLine."System-Unchangable Discounts" := TRUE;
                    NewLine."System-Unchangable Offer" := TRUE;
                    NewLine."System-Block Promotion Price" := TRUE;
                    NewLine."System-Block Periodic Discount" := TRUE;
                    NewLine."FSN Remission No." := lRemissionHeader."No.";
                    NewLine.Description := lRemissionLine.Description;
                    NewLine."Lot No." := lRemissionLine.Lot;
                    NewLine."Expiration Date" := lRemissionLine."Expiration Date";

                    _Price := 0;
                    CASE lRemissionLine.Type OF
                        lRemissionLine.Type::Item:
                            _Price := lRemissionLine."Amount Including VAT" / lRemissionLine.Quantity;
                        ELSE BEGIN
                            _Price := -(lRemissionLine."Amount Including VAT" / lRemissionLine.Quantity);
                        END;
                    END;
                    NewLine.VALIDATE(Price, _Price);
                    NewLine.CalcPrices();
                    NewLine.INSERT(TRUE);
                    lRemissionLine."Line No. Closed" := _NextLine;
                    lRemissionLine."Receipt No. Closed" := POSTrans."Receipt No.";
                    lRemissionLine."POS Terminal No. Closed" := POSTrans."POS Terminal No.";
                    lRemissionLine.MODIFY(TRUE);
                    _NextLine += 10000;
                END;
            UNTIL lRemissionLine.NEXT = 0;

        TextPressedInLine(STRSUBSTNO(lText001, lCompanyInsurer."Coinsurance Text Add", lRemissionHeader."External Document No."), _NextLine, INReceipt);

        lRemissionHeader.Status := lRemissionHeader.Status::Close;
        lRemissionHeader."Receipt No. Closed" := POSTrans."Receipt No.";
        lRemissionHeader."POS Terminal No. Closed" := POSTrans."POS Terminal No.";
        lRemissionHeader.ModifyTrigger();
        lRemissionHeader.MODIFY;
        //JH10092024-1
        lCompanyInsurer2.Reset();
        lCompanyInsurer2.SetRange("No.", lRemissionHeader."Company No.");
        if lCompanyInsurer2.FindFirst() then
            if lCompanyInsurer2."Secondary Customer" then begin
                CustomerCompany.Reset();
                CustomerCompany.SetRange("No.", lRemissionHeader."Customer No.");
                if CustomerCompany.FindFirst() then
                    //Verificar que la empresa tenga el atributo SUB CLIENTE PV
                    if isSubClientEnabled(CustomerCompany) then begin
                        lInsuredLinks.Reset();
                        lInsuredLinks.SetRange(Card, lRemissionHeader."Insured Card No.");
                        if lInsuredLinks.FindFirst() then
                            //Guarda en el infocodo el codigo del cliente secundario
                            saveSubClient(lInsuredLinks."Customer No.");
                    end;
            end;
    end;

    //JH10092024-1 Se crea validacion para insertar infocode cliente secundario
    //de forma automatica en el proceso de InsertRemissionInvoice**************
    local procedure isSubClientEnabled(Customer: Record Customer): Boolean
    var
        attribute: Record "LSC Attribute Value";
    begin
        attribute.SetRange("Attribute Code", 'CLIENTES');
        attribute.SetRange("Link Type", attribute."Link Type"::Customer);
        attribute.SetRange("Link Field 1", Customer."No.");
        attribute.SetRange("Attribute Value", 'SUB CLIENTE PV');
        if not attribute.FindSet() then
            exit(false);

        exit(true);
    end;

    local procedure saveSubClient(CustomerSecondary: Code[20])
    var
        infocode: Record "LSC POS Trans. Infocode Entry";
        posTransaction: Codeunit "LSC POS Transaction";
        session: Codeunit "LSC POS Session";
    begin
        infocode.Init();
        infocode."Receipt No." := posTransaction.GetReceiptNo();
        infocode."Transaction Type" := 0;
        infocode."Line No." := 40;
        infocode.Infocode := 'TEXT';
        infocode.Information := CustomerSecondary;
        infocode."POS Terminal No." := session.TerminalNo();
        infocode."Store No." := session.StoreNo();
        infocode.Date := Today();
        infocode.Time := Time();
        infocode."Staff ID" := session.StaffID();

        if not infocode.Insert(true) then
            infocode.Modify(true);
    end;

    //********************************



    procedure TextPressedInLine(pText: Text[100]; LineLink: Integer; PReceipt: code[20])
    var
        NewLine: Record "LSC POS Trans. Line";
        POSTrans: Record "LSC POS Transaction";
    begin
        //TextPressedInLine 
        if pText = '' then
            exit;

        POSTrans.GET(PReceipt);
        NewLine.Init();
        NewLine."Store No." := POSTrans."Store No.";
        NewLine."POS Terminal No." := POSTrans."POS Terminal No.";
        NewLine."Receipt No." := POSTrans."Receipt No.";

        NewLine."Entry Type" := NewLine."Entry Type"::FreeText;
        NewLine."Text Type" := NewLine."Text Type"::"Freetext Input";
        NewLine.VALIDATE(NewLine.Description, pText);
        NewLine."Line No." := LineLink;
        NewLine.INSERT(TRUE);

        pText := '';
        POSTransaction.SetCurrInput(pText);
        POSLINE.SetCurrentLine(NewLine);
    end;

    //EVENTS
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Transaction", 'OnItemNoPressed', '', true, true)]
    local procedure "POS Transaction_OnItemNoPressed"
    (
        REC: Record "LSC POS Transaction";
        CurrInput: Text;
        var Handled: Boolean
    )
    var
        lText001: Label 'Cant add item in transaction type Remission';
    begin
        if REC."FSN Remission No." then begin
            POSGUI.PosMessage(lText001);
            Handled := true;
        end;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Transaction Events", 'OnAfterValidateIncExpLine', '', true, true)]
    local procedure "POS Transaction Events_OnAfterValidateIncExpLine"
    (
        var POSTransaction: Record "LSC POS Transaction";
        var POSTransLine: Record "LSC POS Trans. Line";
        var CurrInput: Text;
        var Proceed: Boolean
    )
    var
        lText001: Label 'Cant add item in transaction type Remission';
    begin
        if POSTransaction."FSN Remission No." then begin
            POSGUI.PosMessage(lText001);
            Proceed := false;
            Clear(CurrInput);
        end;
    end;

    local procedure SetCustomer(RemissionHeader: Record "FSN Remission Header"; CustomerR: Code[20])
    var
        POSTrans: Record "LSC POS Transaction";
        POSTransLineTB: Record "LSC POS Trans. Line";
        lCustomer: Record Customer;
        LastNoLine: Integer;
    begin
        POSTrans.Get(POSTransaction.GetReceiptNo());
        if CustomerR <> '' then
            POSTrans."Customer No." := CustomerR
        else
            POSTrans."Customer No." := RemissionHeader."Customer No.";
        //POSTrans."FSN Remission No." := true;
        POSTrans.Modify();

        POSTransLineTB.Reset();
        POSTransLineTB.SetRange("Receipt No.", POSTrans."Receipt No.");
        POSTransLineTB.SetRange("Entry Type", POSTransLineTB."Entry Type"::FreeText);
        POSTransLineTB.SetRange("Text Type", POSTransLineTB."Text Type"::"Cust. Text");
        if POSTransLineTB.Find('-') then
            exit;

        LastNoLine := GetLastNoLine(POSTrans."Receipt No.");

        //agregar linea a la transaccion
        POSTransLineTB.Reset();
        POSTransLineTB.init();
        POSTransLineTB.Validate("Receipt No.", POSTrans."Receipt No.");
        POSTransLineTB.Validate("Entry Type", POSTransLineTB."Entry Type"::FreeText);
        POSTransLineTB.Validate("Line No.", LastNoLine);
        POSTransLineTB.Validate("Store No.", POSTrans."Store No.");
        POSTransLineTB.Validate("POS Terminal No.", POSTrans."POS Terminal No.");
        POSTransLineTB.Validate("Text Type", POSTransLineTB."Text Type"::"Cust. Text");
        if POSTrans."Customer No." <> '' then
            if lCustomer.Get(POSTrans."Customer No.") then begin
                POSTransLineTB.Description := CopyStr('Cliente(' + POSTrans."Customer Disc. Group" + ') ' + lCustomer.Name, 1, MAXSTRLEN(POSTransLineTB.Description));
                POSTransLineTB.Validate("Card/Customer/Coup.Item No", lCustomer."No.");
            end;

        POSTransLineTB.Insert(true);
    end;

    local procedure GetLastNoLine(ReceiptNo: Code[20]): Integer
    var
        POStransLine: Record "LSC POS Trans. Line";
    begin
        POStransLine.Reset();
        POStransLine.SetRange("Receipt No.", ReceiptNo);
        if POStransLine.FindLast() then
            exit(POStransLine."Line No." + 10000);
    end;

    local procedure ValidateControl(GlobalPosTransaction: Record "LSC POS Transaction"): Boolean
    var
        myInt: Integer;
        Item: Record Item;
        PosTransLine: Record "LSC POS Trans. Line";
        FSNRemisionLine: Record "FSN Remission Line";
        FSNRemisionHeader: Record "FSN Remission Header";
    begin
        FSNRemisionHeader.Reset();
        FSNRemisionHeader.SetRange("Receipt No. Coinsurance", GlobalPosTransaction."Receipt No.");
        if not FSNRemisionHeader.FindFirst() then begin
            FSNRemisionHeader.Reset();
            FSNRemisionHeader.SetRange("Receipt No. Coinsurance", '');
            FSNRemisionHeader.SetRange("Receipt No. Closed", GlobalPosTransaction."Receipt No.");
            if not FSNRemisionHeader.FindFirst() then
                exit(false);
        end;

        FSNRemisionLine.Reset();
        FSNRemisionLine.SetRange(Type, FSNRemisionLine.Type::Item);
        FSNRemisionLine.SetRange("Document No.", FSNRemisionHeader."No.");
        if FSNRemisionLine.Find('-') then
            repeat
                Item.Reset();
                if Item.Get(FSNRemisionLine."No.") then
                    if (StrPos(Item."LSC Attrib 2 Code", 'CONTROL') > 0) then
                        if not RecetaReg(GlobalPosTransaction) then
                            if not GetRecetas(FSNRemisionHeader."No.", GlobalPosTransaction) then
                                exit(true);
            until FSNRemisionLine.Next() = 0;
    end;
    // se inserta el comodin cuando es CC
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Functions", 'OnBeforeLoadItem', '', true, true)]
    local procedure "LSC POS Functions_OnBeforeLoadItem"(var Line: Record "LSC POS Trans. Line")
    var
        PosFunc: codeunit "LSC POS Functions";
        ErrorText: Text;
        XMLRequest: Text;
        XMLResponse: Text;
        RequestID: Text[50];
        PosMenuLineTemp: Record "LSC POS Menu Line" temporary;
        Processed: Boolean;
        MsgResult: text;
        FSNUtility: Codeunit "FSN Utility";
        Item: Record Item;
    begin
        if Line."Entry Type" = Line."Entry Type"::Item then begin
            if Item.Get(Line.Number) THEN
                if Item."Item Tracking Code" <> '' then begin
                    RequestID := 'FSNCC';
                    Processed := false;
                    FSNUtility.InvokeGlobalChannel(XMLRequest, XMLResponse, RequestID, PosMenuLineTemp, Processed, MsgResult);
                    If Processed then begin
                        Line."Lot No." := '#LOTCOMODIN';
                    end;
                end;
        end;
    end;


    //valida si existe el lote en trans sales entry para reutilizar fecha si no levanta la pagina
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Transaction Events", 'OnAfterInsertItemLine', '', true, true)]
    local procedure "LSC POS Transaction Events_OnAfterInsertItemLine"
    (
        var POSTransaction: Record "LSC POS Transaction";
        var POSTransLine: Record "LSC POS Trans. Line";
        var CurrInput: Text
    )
    var
        Item_l: Record Item;
        Datime: DateTime;
        caption: Label 'Expire Date:';
        Result: Action;
        DateFilt: Date;
        dat: Date;
        TransSalesEntry: Record "LSC Trans. Sales Entry";
        ExpireDatePage: Page "FSN ExpireDate";
        PosMenuLineTemp: Record "LSC POS Menu Line" temporary;
    begin
        DateFilt := 0D;
        IF NOT POSTransLine.IsTemporary THEN//28981
            IF POSTransLine."Entry Type" = POSTransLine."Entry Type"::Item THEN begin
                if Evaluate(DateFilt, '') then;
                IF NOT (POSTransLine."Lot No." IN ['', '#LOTCOMODIN']) AND (POSTransLine."Expiration Date" = DateFilt) THEN begin
                    TransSalesEntry.Reset();
                    TransSalesEntry.SetCurrentKey("Item No.", "Variant Code", Date, "Store No.", "Serial No.", "Lot No.");
                    TransSalesEntry.SetRange(TransSalesEntry."Store No.", POSTransLine."Store No.");
                    TransSalesEntry.SetRange(TransSalesEntry."Item No.", POSTransLine.Number);
                    TransSalesEntry.SetFilter(TransSalesEntry."Lot No.", POSTransLine."Lot No.");
                    if TransSalesEntry.Find('-') then begin
                        POSTransLine."Expiration Date" := TransSalesEntry."Expiration Date";
                        POSTransLine.Modify();
                    end else begin
                        Item_l.Get(POSTransLine.Number);
                        POSSession.SetValue('#NOLOTE', Item_l."No.");
                        POSSession.SetValue('#LOTELINE', FORMAT(POSTransLine."Line No."));
                        ExpireDatePage.SetRecord(POSTransLine);
                        ExpireDatePage.run();
                        //POSGUI.OpenCalendar(CopyStr(StrSubstNo(caption, Item_l.Description), 1, 50), Datime, Result);
                    end;
                end;
            end;
    end;


    //levantar pagina con el evento global
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
        ExpireDatePage: Page "FSN ExpireDate";
        POSTransLine: Record "LSC POS Trans. Line";
        ValLineNo: Integer;
    begin

        if RequestID = '#RUNPAGELOT' then begin
            if Evaluate(ValLineNo, MsgResult) then;
            POSTransLine.Reset();//28981 -2
            POSTransLine.SETRANGE(POSTransLine."Receipt No.", POSTransaction.GetReceiptNo());
            POSTransLine.SETRANGE(POSTransLine."Entry Type", POSTransLine."Entry Type"::Item);
            POSTransLine.SETRANGE(POSTransLine.Number, XMLRequest);
            POSTransLine.SetRange(POSTransLine."Line No.", ValLineNo);
            POSTransLine.SETFILTER(POSTransLine."Entry Status", '<>%1', POSTransLine."Entry Status"::Voided);
            if POSTransLine.FindFirst() then begin
                POSSESSION.SetValue('#NOLOTE', POSTransLine.Number);
                POSSession.SetValue('#LOTELINE', FORMAT(POSTransLine."Line No."));
                ExpireDatePage.SetRecord(POSTransLine);
                ExpireDatePage.run();
                XMLRequest := '';
            end;
        end;
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
        pErrorText: text;
        pREC: Record "LSC POS Transaction";
        POSTransC: Codeunit "LSC POS Transaction";
        menuLine: Record "LSC POS Menu Line";
        XMLRequest: Text;
        XMLResponse: Text;
        RequestID: Text[50];
        PosMenuLineTemp: Record "LSC POS Menu Line" temporary;
        Processed: Boolean;
        MsgResult: text;
        GlobalPosMenuLine: Record "LSC POS Menu Line";
        FSNUtility: Codeunit "FSN Utility";
    begin

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
    end;
}


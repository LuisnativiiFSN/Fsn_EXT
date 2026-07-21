codeunit 50011 "FSN Benef. Father/Son Event"
{
    //TableNo = "POS Menu Line";

    trigger OnRun()
    begin


    end;

    var
        GlobalRec: Record "LSC POS Menu Line";
        POSTransC: Codeunit "LSC POS Transaction";
        POSCtrl: Codeunit "LSC POS Controller";
        POSGUI: Codeunit "LSC POS GUI";
        BenefPOSMenutmp: Record "LSC POS Menu Line" temporary;
        lText004: Label 'No. tarjeta de Titular';


    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Transaction Events", 'OnAfterValidateCustomer', '', true, true)]
    local procedure "POS Transaction Events_OnAfterValidateCustomer"
    (
        var POSTransaction: Record "LSC POS Transaction";
        var POSTransLine: Record "LSC POS Trans. Line";
        var CurrInput: Text;
        var CustomerOrCardNo: Code[20]
    )
    var
        Customer: Record Customer;
        Beneficiaries: Codeunit "FSN Benef. Father/Son Event";
        param: Record "FSN Parameter";
        lText004: Label 'No. tarjeta de Titular';
        lResult: Action;
        ResultTex: Text;
        POSSESSION: Codeunit "LSC POS Session";
    begin
        if not ValueCustBeneficiary(POSTransaction) then begin
            Customer.RESET;
            Customer.SETRANGE(Customer."No.", CustomerOrCardNo);
            IF Customer.FINDFIRST THEN
                IF Customer."FSN Request Beneficiary" THEN BEGIN
                    POSSESSION.SetValue('RECEIPTBEN', 'TRUE');
                    POSGUI.OpenAlphabeticKeyboardEx(lText004, '', FALSE, format(POSTransaction."Receipt No."));
                END;
        end;

    END;

    procedure ValueCustBeneficiary(POSTransaction: Record "LSC POS Transaction"): Boolean
    var
        myInt: Integer;
        POSLine_l: Record "LSC POS Trans. Line";
        CustomerL: Record Customer;
    begin
        POSLine_l.Reset();
        POSLine_l.SetRange(POSLine_l."Store No.", POSTransaction."Store No.");
        POSLine_l.SetRange(POSLine_l."POS Terminal No.", POSTransaction."POS Terminal No.");
        POSLine_l.SetRange(POSLine_l."Receipt No.", POSTransaction."Receipt No.");
        POSLine_l.SetRange(POSLine_l."Entry Type", POSLine_l."Entry Type"::FreeText);
        POSLine_l.SetRange(POSLine_l."Entry Status", POSLine_l."Entry Status"::" ");
        POSLine_l.SetRange(POSLine_l."Text Type", 4);
        POSLine_l.SetRange(POSLine_l."FSN Remission No.", 'ENERGETICAS');
        if POSLine_l.FindFirst() then
            exit(true)
        else
            exit(false);
        exit(false);
    end;


    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Controller", 'OnKeyboardResult', '', true, true)]
    local procedure "EPOS Controler_OnKeyboardResult"
(
    payload: Text;
    inputValue: Text;
    resultOK: Boolean;
    var processed: Boolean
)
    var
        posTransac: record "LSC POS Transaction";
        CustomerL: Record Customer;
        POSSESSION: Codeunit "LSC POS Session";
    begin

        IF (POSSESSION.GetValue('RECEIPTBEN') = 'TRUE') THEN BEGIN
            posTransac.RESET;
            posTransac.SetRange(posTransac."Receipt No.", payload);
            IF posTransac.FINDFIRST THEN begin
                CustomerL.RESET;
                CustomerL.SETRANGE(CustomerL."No.", posTransac."Customer No.");
                IF CustomerL.FINDFIRST THEN begin
                    IF CustomerL."FSN Request Beneficiary" THEN BEGIN
                        BeneficiariesComan(inputValue, resultOK, processed, posTransac."Receipt No.");
                        POSSESSION.SetValue('RECEIPTBEN', '');
                    end;
                end;
            end;
        END;
    end;


    procedure BeneficiariesComan(CurrInput: Text; ResultOk: Boolean; var Processed: Boolean; var CustomerReceipt: Code[20])
    var
        Footfall: Decimal;
        DataTypeErr: Label 'No puede ser vacio';
        xSelBene: Record "SeleccionBeneficiario";
        posTransaB: record "LSC POS Transaction";
        FSNBFatherSon: Record "FSN Benef. Father Son" temporary;
        xBene: Record "FSN Benef. Father Son";
        xBeneTitular: Record "FSN Benef. Father Son";
        xBene2: Record "FSN Benef. Father Son";
        xPOStemp: Record "LSC POS Trans. Line";
        POSLine_: Record "LSC POS Trans. Line";
        RecRef: RecordRef;
        ActionBenef: Action;
        mTitu: Code[20];
        mBene: Code[20];
        NoLine: Integer;
        xNIT: Code[20];
        Result: text;
        xResult: Boolean;
        lText001: Label 'El nombre del beneficiario no puede estar vacío';
        lText002: Label 'El nombre no puede estar vacío';
        lText003: Label 'El codigo de titular no es valido';
        lText004: Label 'El numero de Tarjeta es %1, desea continuar?';
        lFilterTitular: Label 'TITULAR';
        MailValue: Text[102];
    begin
        Processed := true;
        if not ResultOk then
            exit;
        if CurrInput <> '' then begin
            posTransaB.RESET;
            posTransaB.SetRange(posTransaB."Receipt No.", CustomerReceipt);
            IF posTransaB.FINDFIRST THEN begin
                mTitu := CurrInput;
                xSelBene.DELETEALL;
                CLEAR(xBene);
                xBene.SETCURRENTKEY("Customer No.", Titular);
                xBene.SETFILTER("Customer No.", '%1', posTransaB."Customer No.");
                xBene.SETFILTER(Titular, '%1', CurrInput);
                IF xBene.FIND('-') THEN BEGIN
                    xResult := TRUE;
                    REPEAT
                        FSNBFatherSon.INIT;
                        FSNBFatherSon."Customer No." := posTransaB."Customer No.";
                        FSNBFatherSon."Card No." := xBene."Card No.";
                        FSNBFatherSon.Name := xBene.Name;
                        FSNBFatherSon.Poliza := xBene.Poliza;
                        FSNBFatherSon.Relation := xBene.Relation;
                        FSNBFatherSon.Titular := xBene.Titular;
                        FSNBFatherSon.mail := xBene.mail;
                        FSNBFatherSon.INSERT;
                    UNTIL xBene.NEXT = 0;
                end;
                Clear(MailValue);
                IF NOT xResult THEN BEGIN
                    POSGUI.PosMessage('Codigo de Beneficiario Invalido. Reintente...');
                END ELSE BEGIN
                    FSNBFatherSon.Reset;
                    FSNBFatherSon.SetFilter(FSNBFatherSon."Card No.", '<>%1', '');
                    IF FSNBFatherSon.FINDFIRST THEN BEGIN
                        Commit();
                        ActionBenef := Page.RunModal(Page::"FSN Beneficiaries Father/Son", FSNBFatherSon);
                    end;
                    IF ActionBenef = Action::LookupOK then begin
                        mBene := FSNBFatherSon."Card No.";
                        if POSGUI.PosConfirm(STRSUBSTNO(lText004, mBene), true) then begin
                            xBene.GET(posTransaB."Customer No.", mTitu);
                            IF xBene.Name = '' THEN
                                ERROR(lText002);
                            // IF (FORMAT(xBene.Relation) <> lFilterTitular) THEN BEGIN
                            if mBene <> mTitu then begin
                                IF NOT (xBene2.GET(posTransaB."Customer No.", mBene)) THEN
                                    ERROR(lText003);
                                IF (xBene2.Name = '') THEN
                                    ERROR(lText001);
                            end;
                            //END;

                            NoLine := 0;
                            xPOStemp.SETRANGE("Receipt No.", CustomerReceipt);
                            IF xPOStemp.FIND('+') THEN
                                NoLine := xPOStemp."Line No.";

                            if xBene2.mail <> '' then
                                MailValue := xBene2.mail
                            else begin
                                if xBeneTitular.get(xBene2."Customer No.", xBene2.Titular) then
                                    MailValue := xBeneTitular.mail;
                            end;

                            POSLine_.Reset();
                            POSLine_.SetRange(POSLine_."Receipt No.", POSTransC.GetReceiptNo());
                            POSLine_.SetRange(POSLine_."Text Type", POSLine_."Text Type"::"TD Text");
                            if POSLine_.find('-') then begin
                                repeat
                                    IF ((COPYSTR(POSLine_.Description, 1, 7)) = 'TITULAR') then begin
                                        POSLine_.Description := COPYSTR('TITULAR : ' + xBene."Card No." + ' - ' + xBene.Name, 1, 50);
                                        POSLine_.Modify()
                                    end;

                                    IF ((COPYSTR(POSLine_.Description, 1, 12)) = 'BENEFICIARIO') then begin
                                        POSLine_.Description := COPYSTR('BENEFICIARIO : ' + xBene2.Name, 1, 50);
                                        POSLine_.Modify()
                                    end;

                                    IF ((COPYSTR(POSLine_.Description, 1, 6)) = 'POLIZA') then begin
                                        POSLine_.Description := COPYSTR('POLIZA : ' + xBene2.Poliza, 1, 50);
                                        POSLine_.Modify()
                                    end;

                                    IF ((COPYSTR(POSLine_.Description, 1, 3)) = 'NIT') then begin
                                        POSLine_.Description := COPYSTR('NIT : ' + xBene2.NIT, 1, 50);
                                        POSLine_.Modify()
                                    end;

                                    IF ((COPYSTR(POSLine_.Description, 1, 4)) = 'MAIL') then begin
                                        POSLine_.Description := COPYSTR('MAIL : ' + MailValue, 1, 50);
                                        POSLine_.Modify();

                                        if MailValue <> '' then
                                            SaveInfocode(posTransaB, MailValue);

                                    end;

                                UNTIL POSLine_.NEXT = 0;
                            end else begin

                                CLEAR(xPOStemp);

                                // Insertar Infocode del Titular
                                NoLine += 10000;
                                xPOStemp.INIT();
                                xPOStemp."Entry Type" := xPOStemp."Entry Type"::FreeText;
                                xPOStemp."Receipt No." := posTransaB."Receipt No.";
                                xPOStemp."Line No." := NoLine;
                                xPOStemp."Entry Status" := 0;
                                xPOStemp."Store No." := posTransaB."Store No.";
                                xPOStemp."POS Terminal No." := posTransaB."POS Terminal No.";
                                xPOStemp."Text Type" := 4;
                                xPOStemp.Description := COPYSTR('TITULAR : ' + xBene."Card No." + ' - ' + xBene.Name, 1, 50);
                                xPOStemp."FSN Remission No." := 'ENERGETICAS';
                                xPOStemp.INSERT(TRUE);
                                xNIT := xBene.NIT;

                                xBene.GET(posTransaB."Customer No.", mBene);

                                // Insertar Infocode del Beneficiario
                                NoLine += 10000;
                                xPOStemp.INIT();
                                xPOStemp."Entry Type" := xPOStemp."Entry Type"::FreeText;
                                xPOStemp."Receipt No." := posTransaB."Receipt No.";
                                xPOStemp."Line No." := NoLine;
                                xPOStemp."Entry Status" := 0;
                                xPOStemp."Store No." := posTransaB."Store No.";
                                xPOStemp."POS Terminal No." := posTransaB."POS Terminal No.";
                                xPOStemp."Text Type" := 4;
                                xPOStemp.Description := COPYSTR('BENEFICIARIO : ' + xBene2.Name, 1, 50);
                                xPOStemp."FSN Remission No." := 'ENERGETICAS';
                                xPOStemp.INSERT(TRUE);

                                // Insertar Infocode de Poliza
                                NoLine += 10000;
                                xPOStemp.INIT();
                                xPOStemp."Entry Type" := xPOStemp."Entry Type"::FreeText;
                                xPOStemp."Receipt No." := posTransaB."Receipt No.";
                                xPOStemp."Line No." := NoLine;
                                xPOStemp."Entry Status" := 0;
                                xPOStemp."Store No." := posTransaB."Store No.";
                                xPOStemp."POS Terminal No." := posTransaB."POS Terminal No.";
                                xPOStemp."Text Type" := 4;
                                xPOStemp.Description := COPYSTR('POLIZA : ' + xBene2.Poliza, 1, 50);
                                xPOStemp."FSN Remission No." := 'ENERGETICAS';
                                xPOStemp.INSERT(TRUE);

                                // Insertar Infocode del DUI de titular
                                NoLine += 10000;
                                xPOStemp.INIT();
                                xPOStemp."Entry Type" := xPOStemp."Entry Type"::FreeText;
                                xPOStemp."Receipt No." := posTransaB."Receipt No.";
                                xPOStemp."Line No." := NoLine;
                                xPOStemp."Entry Status" := 0;
                                xPOStemp."Store No." := posTransaB."Store No.";
                                xPOStemp."POS Terminal No." := posTransaB."POS Terminal No.";
                                xPOStemp."Text Type" := 4;
                                xPOStemp.Description := COPYSTR('NIT : ' + xBene2.NIT, 1, 50);
                                xPOStemp."FSN Remission No." := 'ENERGETICAS';
                                xPOStemp.INSERT(TRUE);

                                NoLine += 10000;
                                xPOStemp.INIT();
                                xPOStemp."Entry Type" := xPOStemp."Entry Type"::FreeText;
                                xPOStemp."Receipt No." := posTransaB."Receipt No.";
                                xPOStemp."Line No." := NoLine;
                                xPOStemp."Entry Status" := 0;
                                xPOStemp."Store No." := posTransaB."Store No.";
                                xPOStemp."POS Terminal No." := posTransaB."POS Terminal No.";
                                xPOStemp."Text Type" := 4;
                                xPOStemp.Description := COPYSTR('MAIL : ' + MailValue, 1, 50);
                                xPOStemp."FSN Remission No." := 'ENERGETICAS';
                                xPOStemp.INSERT(TRUE);

                                if MailValue <> '' then
                                    SaveInfocode(posTransaB, MailValue);
                            end;
                        end else begin
                            BeneficiariesComan(CurrInput, ResultOk, Processed, CustomerReceipt);
                        end;
                    end;
                END;
            end;
        end;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Controller", 'OnPOSEvent', '', true, true)]
    local procedure "LSC POS Controller_OnPOSEvent"
        (
        var PosEvent: Codeunit "LSC POS Event";
        var SuppressEvent: Boolean
        )
    var
        POSLines: Codeunit "LSC POS Trans. Lines";
        POSLine_l: Record "LSC POS Trans. Line";
        POSCardEntryl: Record "LSC POS Card Entry";
        ReceiptB: Code[20];
        Processed: Boolean;
        CustomerL: Record Customer;
        POSTransaction: Record "LSC POS Transaction";
        InfoEntry: Record "LSC POS Trans. Infocode Entry";
        caption: Label 'Ingrese correo del beneficiario';
        Result: Action;
        POSSESSION: Codeunit "LSC POS Session";
        XMLRequest: Text;
        XMLResponse: Text;
        RequestID: Text[50];
        PosMenuLineTemp: Record "LSC POS Menu Line" temporary;
        MsgResult: text;
        FSNUtility: Codeunit "FSN Utility";
        TEXT000: Label 'El cliente %1 no esta permitido para ingresar correo electronico.';
    begin
        if PosEvent.ActivePanel = '#POS' THEN
            if PosEvent.EventType in [
                Enum::"LSC POS Event Type"::DATAROWDOUBLECLICK
            ] then begin
                POSLines.GetCurrentLine(POSLine_l);
                if (POSLine_l."Entry Type" = POSLine_l."Entry Type"::FreeText) and
                    (POSLine_l."Entry Status" = POSLine_l."Entry Status"::" ") and
                    (POSLine_l."Text Type" = POSLine_l."Text Type"::"Cust. Text") then begin
                    ReceiptB := POSTransC.GetReceiptNo();
                    Processed := true;
                    CustomerL.RESET;
                    CustomerL.SETRANGE(CustomerL."No.", POSLine_l."Card/Customer/Coup.Item No");
                    IF CustomerL.FINDFIRST THEN begin
                        IF CustomerL."FSN Request Beneficiary" THEN BEGIN
                            POSSESSION.SetValue('RECEIPTBEN', 'TRUE');
                            POSGUI.OpenAlphabeticKeyboardEx(lText004, '', FALSE, format(ReceiptB));
                        end;
                    end;
                end;

                RequestID := 'FSNCC';
                Processed := false;
                FSNUtility.InvokeGlobalChannel(XMLRequest, XMLResponse, RequestID, PosMenuLineTemp, Processed, MsgResult);
                If Processed then begin
                    if (POSLine_l."Entry Type" = POSLine_l."Entry Type"::FreeText) AND (POSLine_l."FSN Remission No." = 'ENERGETICAS') and
                        (POSLine_l."Entry Status" = POSLine_l."Entry Status"::" ") and ((COPYSTR(POSLine_l.Description, 1, 4) = 'MAIL')) THEN
                        if POSTransaction.get(POSLine_l."Receipt No.") then begin
                            CustomerL.RESET;
                            CustomerL.SETRANGE(CustomerL."No.", POSTransaction."Customer No.");
                            IF CustomerL.FINDFIRST THEN begin
                                IF CustomerL."FSN Request Beneficiary" THEN BEGIN
                                    if ValBeneficiariesExclude(POSTransaction."Customer No.") then begin
                                        POSSESSION.SetValue('#MAILBC', 'TRUE');
                                        POSGUI.OpenAlphabeticKeyboard(CopyStr(StrSubstNo(caption), 1, 50), '', Result, true);
                                    end else
                                        POSGUI.PosMessage(StrSubstNo(TEXT000, CustomerL.Name));
                                END;
                            end;
                        end;
                END;
            end;
    end;


    procedure ValBeneficiariesExclude(CustCode: Code[20]): Boolean
    var
        ParameterBf: Record "FSN Parameter";
    begin
        if ParameterBf.get('BENEFICIARIES', 'EXCLUDE') and ParameterBf.Activo then begin
            IF (StrPos(ParameterBf."String Parameters 1 Json" + ParameterBf."String Parameters 1 Json", CustCode) > 0) then
                exit(true)
            else
                exit(false);
        end;
        exit(false);
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
        PosTransactionB: Record "LSC POS Transaction";
        POSSESSION: Codeunit "LSC POS Session";
        gPosTransaction: Codeunit "LSC POS Transaction";
        XMLRequest: Text;
        XMLResponse: Text;
        RequestID: Text[50];
        PosMenuLineTemp: Record "LSC POS Menu Line" temporary;
        MsgResult: text;
        FSNUtility: Codeunit "FSN Utility";
        Processedv: Boolean;
        InfoText: Label 'El correo "%1" no tiene un formato válido.';
    BEGIN
        RequestID := 'FSNCC';
        Processedv := false;
        FSNUtility.InvokeGlobalChannel(XMLRequest, XMLResponse, RequestID, PosMenuLineTemp, Processedv, MsgResult);
        If Processedv then begin
            IF POSSESSION.GetValue('#MAILBC') = 'TRUE' THEN
                IF resultOK THEN begin
                    if PosTransactionB.get(gPosTransaction.GetReceiptNo()) then begin
                        if not EsCorreoValido(inputValue) then begin
                            POSSESSION.SetValue('#MAILBC', 'FALSE');
                            Message(InfoText, inputValue);
                            exit;
                        end else
                            InsetEmailCustBeneficiary(PosTransactionB, inputValue);
                    end;
                    POSSESSION.SetValue('#MAILBC', 'FALSE');
                END ELSE
                    POSSESSION.SetValue('#MAILBC', 'FALSE');
        END;
    END;

    procedure EsCorreoValido(Correo: Text): Boolean
    var
        RegEx: DotNet Regex; // Microsoft.Dynamics.Nav.Runtime: Regex
    begin
        exit(RegEx.IsMatch(Correo, '^[\w\.-]+@[\w\.-]+\.\w{2,}$'));
    end;

    procedure InsetEmailCustBeneficiary(posTransaB: Record "LSC POS Transaction"; mail: Text)
    var
        xPOStemp: Record "LSC POS Trans. Line";
        InfoEntry: Record "LSC POS Trans. Infocode Entry";
    begin

        if getCustGenericEmail(posTransaB, InfoEntry, mail) then begin
            xPOStemp.Reset();
            xPOStemp.SetRange(xPOStemp."Store No.", posTransaB."Store No.");
            xPOStemp.SetRange(xPOStemp."POS Terminal No.", posTransaB."POS Terminal No.");
            xPOStemp.SetRange(xPOStemp."Receipt No.", posTransaB."Receipt No.");
            xPOStemp.SetRange(xPOStemp."Text Type", xPOStemp."Text Type"::"TD Text");
            xPOStemp.SetRange(xPOStemp."FSN Remission No.", 'ENERGETICAS');
            if xPOStemp.Find('-') then begin
                repeat
                    IF ((COPYSTR(xPOStemp.Description, 1, 4)) = 'MAIL') then begin
                        xPOStemp.Description := COPYSTR('MAIL : ' + mail, 1, 50);
                        xPOStemp.Modify(true);

                        InfoEntry.Information := CopyStr(mail, 1, 100);
                        InfoEntry.Modify();
                    end;
                until xPOStemp.Next() = 0;
            end;
        end else begin
            xPOStemp.INIT();
            xPOStemp."Store No." := posTransaB."Store No.";
            xPOStemp."POS Terminal No." := posTransaB."POS Terminal No.";
            xPOStemp."Receipt No." := posTransaB."Receipt No.";
            xPOStemp."Entry Type" := xPOStemp."Entry Type"::FreeText;
            xPOStemp."Line No." := LastPosTransLine(posTransaB) + 10000;
            xPOStemp."Entry Status" := 0;
            xPOStemp."Text Type" := 4;
            xPOStemp.Description := COPYSTR('MAIL : ' + mail, 1, 50);
            xPOStemp."FSN Remission No." := 'ENERGETICAS';
            if not xPOStemp.INSERT(TRUE) then
                xPOStemp.Modify(TRUE);

            InfoEntry.Init();
            InfoEntry."Store No." := xPOStemp."Store No.";
            InfoEntry."POS Terminal No." := xPOStemp."POS Terminal No.";
            InfoEntry."Receipt No." := xPOStemp."Receipt No.";
            InfoEntry."Transaction Type" := 0;
            InfoEntry."Line No." := 90;
            InfoEntry.Infocode := 'EMAILTEXT';
            InfoEntry.Information := CopyStr(mail, 1, 100);
            InfoEntry.Date := Today;
            InfoEntry.Time := Time;
            if not InfoEntry.Insert() then
                InfoEntry.Modify();
        end;
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

    local procedure getCustGenericEmail(posTransacB: Record "LSC POS Transaction"; var InfoEntry: Record "LSC POS Trans. Infocode Entry"; mail: Text): Boolean
    var

    begin
        InfoEntry.Reset();
        InfoEntry.SetRange(InfoEntry."Store No.", posTransacB."Store No.");
        InfoEntry.SetRange(InfoEntry."POS Terminal No.", posTransacB."POS Terminal No.");
        InfoEntry.SetRange(InfoEntry."Receipt No.", posTransacB."Receipt No.");
        InfoEntry.SetRange(InfoEntry.Infocode, 'EMAILTEXT');
        InfoEntry.SetRange(InfoEntry."Line No.", 90);
        if InfoEntry.FindFirst() then
            exit(true)
        else begin
            InfoEntry.Init();
            InfoEntry."Store No." := posTransacB."Store No.";
            InfoEntry."POS Terminal No." := posTransacB."POS Terminal No.";
            InfoEntry."Receipt No." := posTransacB."Receipt No.";
            InfoEntry."Transaction Type" := 0;
            InfoEntry."Line No." := 90;
            InfoEntry.Infocode := 'EMAILTEXT';
            InfoEntry.Information := CopyStr(mail, 1, 100);
            InfoEntry.Date := Today;
            InfoEntry.Time := Time;
            if not InfoEntry.Insert() then
                InfoEntry.Modify();
            exit(true);
        end;
    end;

    procedure SaveInfocode(xPOStemp: Record "LSC POS Transaction"; mail: Text)
    var
        InfoEntry: Record "LSC POS Trans. Infocode Entry";
    begin
        InfoEntry.Init();
        InfoEntry."Store No." := xPOStemp."Store No.";
        InfoEntry."POS Terminal No." := xPOStemp."POS Terminal No.";
        InfoEntry."Receipt No." := xPOStemp."Receipt No.";
        InfoEntry."Transaction Type" := 0;
        InfoEntry."Line No." := 90;
        InfoEntry.Infocode := 'EMAILTEXT';
        InfoEntry.Information := CopyStr(mail, 1, 100);
        InfoEntry.Date := Today;
        InfoEntry.Time := Time;
        if not InfoEntry.Insert() then
            InfoEntry.Modify();
    end;

}
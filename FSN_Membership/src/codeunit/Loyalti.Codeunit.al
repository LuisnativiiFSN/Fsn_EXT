/// <summary>
/// Codeunit FSN Loyalty (ID 50095).
/// </summary>
Codeunit 50095 "FSN Loyalty"
{
    SingleInstance = true;
    TableNo = "LSC POS Menu Line";

    VAR
        Customer: Record Customer;
        Customer2: Record Customer;
        rMembersAccount: Record "LSC Member Account";
        rMemberContact: Record "LSC Member Contact";
        rMembershipCard: Record "LSC Membership Card";
        GlobalRec: Record "LSC POS Menu Line";
        PosTransConfirt: Record "LSC POS Transaction";
        PosContext_g: Codeunit "LSC POS Context";
        eposInterface: Codeunit "LSC POS Control Interface";
        PosCtrl_g: Codeunit "LSC POS Control Interface";
        POSGUI: Codeunit "LSC POS GUI";
        POSSession: Codeunit "LSC POS Session";
        NewRecord: Boolean;
        staffManager: Boolean;
        Text002: Label 'Password must be manager';
        text01: Text;
        ErrorText: Text[250];

    trigger OnRun()
    begin
        GlobalRec.COPY(Rec);
        case "Pos Event Type" of
            "Pos Event Type"::BUTTONPRESS:
                CASE Command OF
                //'FSNPANELVIP':
                //MembershipCardConfirm(PosTransaction, text01);//ShowSpecificPanel();
                END;
        end;
    end;

    PROCEDURE AddCard(Account: Code[100]; CardNo: Text; Beneficiario: Text[100]; Store: Code[10]; SalesStaff: Code[10]; pClubCode: Code[10]; pSchemeCode: Code[10]);
    VAR
        rMembershipCard: Record "LSC Membership Card";
    BEGIN
        IF rMembershipCard.GET(CardNo) THEN
            EXIT;
        //Adicion de nueva tarjeta
        rMembershipCard.INIT;
        rMembershipCard."Club Code" := pClubCode;
        rMembersAccount."Scheme Code" := pSchemeCode;
        rMembershipCard.VALIDATE("Account No.", Account);
        rMembershipCard."Allocated to Store" := Store;
        rMembershipCard."FSN SalesStaff" := SalesStaff;
        rMembershipCard."FSN TimeRenewalMembership" := TIME;
        rMembershipCard."Card No." := CardNo;
        rMembershipCard."FSN Beneficiary" := Beneficiario;
        rMembershipCard.INSERT(TRUE);

        IF rMembersAccount.GET(rMembershipCard."Account No.") THEN BEGIN
            CLEAR(Customer2);
            IF Customer.GET(rMembersAccount."Linked To Customer No.") THEN BEGIN
                Customer2 := Customer;
                Customer2."Customer Disc. Group" := 'VIP';
                Customer2.MODIFY(TRUE);
            END;
            rMembersAccount."Club Code" := 'VIP';
            rMembersAccount."Scheme Code" := 'VIP';
            rMembersAccount.MODIFY(TRUE);
        END;
    END;

    procedure GetMemberAccountPointBalance(POST: Record "LSC POS Transaction"): Text
    var
        POSTrans: Record "LSC POS Transaction";
        PosFunc: codeunit "LSC POS Functions";
        POSTransC: Codeunit "LSC POS Transaction";
    begin
        exit(Format(POST."Starting Point Balance"))
        /* if POSSession.GetValue('MemberAccountPointBalance') = '' then begin
            if (POSTrans."Member Card No." <> '') then begin
                if (POSTrans."Starting Point Balance" <> 0) then
                    exit(Format(POSTrans."Starting Point Balance"))
            end else begin
                exit('');
            end;
        end else begin
            exit(format(POSSession.GetValue('MemberAccountPointBalance')));
        end; */
    end;

    PROCEDURE InsertNew("No.": Code[20]; Name: Text; LinkedToCustomer: Code[20]; Direccion1: Text[50]; Direccion2: Text[50]; Email: Text[80]; Telefono: Text[30]; Celular: Text[30]; DateOfBirth: Date; Genero: Text; pClubCode: Code[10]; pSchemeCode: Code[10]);
    BEGIN
        IF ((STRLEN(LinkedToCustomer) < 5) AND (COPYSTR(LinkedToCustomer, 1, 1) = 'G')) OR ((COPYSTR(LinkedToCustomer, 1, 1) = 'V1')) THEN
            ERROR('No puede afiliar cliente General o V1');

        IF rMembersAccount.GET("No.") THEN
            NewRecord := FALSE
        ELSE
            NewRecord := TRUE;

        IF NewRecord THEN
            rMembersAccount.INIT;
        rMembersAccount."No." := "No.";
        rMembersAccount.Description := Name;
        rMembersAccount."Linked To Customer No." := LinkedToCustomer;

        CLEAR(Customer2);
        IF Customer.GET(LinkedToCustomer) THEN BEGIN
            Customer2 := Customer;
            Customer2."Customer Disc. Group" := pClubCode;
            Customer2.MODIFY(TRUE);
        END;

        rMembersAccount."Club Code" := pClubCode;
        rMembersAccount."Scheme Code" := pSchemeCode;

        rMembersAccount."Price Group" := 'ALL';
        IF NewRecord THEN
            rMembersAccount.INSERT(TRUE)
        ELSE
            IF NOT NewRecord THEN
                rMembersAccount.MODIFY(TRUE);

        IF rMemberContact.GET("No.", "No.") THEN BEGIN
            rMemberContact.VALIDATE(Name, Name);
            rMemberContact.Address := Direccion1;
            rMemberContact."Address 2" := Direccion2;
            rMemberContact.VALIDATE("E-Mail", Email);
            rMemberContact."Phone No." := Telefono;
            rMemberContact."Mobile Phone No." := Celular;
            CASE Genero OF
                'Male':
                    rMemberContact.Gender := rMemberContact.Gender::Male;
                'Female':
                    rMemberContact.Gender := rMemberContact.Gender::Female;
            END;

            rMemberContact.VALIDATE("Date of Birth", DateOfBirth);

            rMemberContact."Marital Status" := rMemberContact."Marital Status"::Single;
            rMemberContact.MODIFY(TRUE);
        END;
    END;

    procedure MembershipCardConfirm(pPOSTransaction: Record "LSC POS Transaction"; var ErrorText: Text): Boolean
    var
        lAccount: Record "LSC Member Account";
        lScheme: Record "LSC Member Scheme";
        lMemberShip: Record "LSC Membership Card";
        lMostrarPagos: Record "LSC POS Trans. Line";
        POSCtrl: Codeunit "LSC POS Control Interface";
        POSReceipt: Codeunit "LSC POS Transaction";
        POSView: Codeunit "LSC POS View";
        ScanVipPage: Page "FSN Scan VIP";
        Manager: Boolean;
        lSchemeCode: Code[10];
        lText001: Label 'Card %1 not exits';
        lText002: Label '%1 is not valid';
        lText003: Label 'Card be scanned, try again';
        lText004: Label 'Not match. Expected card %1, scann %2';
        CodigoVip: Text;
        Password: Text;
        SetNewStaffID: Text;
        StaffID: Text;
        Workshift: Text;
    begin
        CodigoVip := '';
        pPOSTransaction.Reset();
        if pPOSTransaction.Get(POSReceipt.GetReceiptNo()) then

            /*StaffID := POSCtrl.GetInputText(POSSession.StaffInputID);
            Password := POSCtrl.GetInputText(POSSession.PasswordInputID);
            Workshift := CopyStr(POSCtrl.GetInputText(POSSession.WorkShiftInputID), 1, 1);

            if StaffID = '' then
                exit;

            if not POSView.LoginEx(Manager, SetNewStaffID, false, StaffID, Password, Workshift) then
                exit;*/

        IF pPOSTransaction."Member Card No." = '' THEN BEGIN
                ErrorText := STRSUBSTNO(lText001, pPOSTransaction."Member Card No.");
                EXIT(FALSE);
            END;
        IF NOT lMemberShip.GET(pPOSTransaction."Member Card No.") THEN BEGIN
            ErrorText := STRSUBSTNO(lText001, pPOSTransaction."Member Card No.");
            EXIT(FALSE);
        END;
        lSchemeCode := lMemberShip."Scheme Code";
        IF lSchemeCode = '' THEN
            IF NOT lAccount.GET(lMemberShip."Account No.") THEN BEGIN
                ErrorText := STRSUBSTNO(lText002, lAccount.TABLECAPTION);
                EXIT(FALSE);
            END ELSE
                lSchemeCode := lAccount."Scheme Code";
        IF (lSchemeCode = '') OR NOT (lScheme.GET(lSchemeCode)) THEN BEGIN
            ErrorText := STRSUBSTNO(lText002, lScheme.TABLECAPTION);
            EXIT(FALSE);
        END;
        lMostrarPagos.RESET;
        lMostrarPagos.SETRANGE(lMostrarPagos."Receipt No.", pPOSTransaction."Receipt No.");
        //OLOPEZ lMostrarPagos.SETRANGE(lMostrarPagos."Is Member", TRUE);
        IF lMostrarPagos.FINDFIRST THEN BEGIN
            //PosCtrl_g.ShowPosLoginDialog(true, '');
        END;

        IF (lScheme.Code = 'VIP_BA') OR pPOSTransaction."Sale Is Return Sale" THEN BEGIN//Logical static
            PosCtrl_g.ShowPanelModal('#FSNLOGIN', 'LOGINMANAGERVIP');
            EXIT(FALSE);
        END ELSE BEGIN
            //CodigoVip := pPOSTransaction."Member Card No.";
            CodigoVip := ScanVipPage.GetCodigoVIP();
            IF (CodigoVip = '') or (CodigoVip <> pPOSTransaction."Member Card No.") THEN BEGIN
                ErrorText := STRSUBSTNO(lText004, pPOSTransaction."Member Card No.", CodigoVip);
                EXIT(FALSE);
            END ELSE BEGIN
                EXIT(TRUE);
            END;
        END;
    end;

    PROCEDURE RenewCard(CardNo: Text; Store: Code[10]; SalesStaff: Code[10]);
    BEGIN
        IF rMembershipCard.GET(CardNo) THEN BEGIN
            rMembershipCard."FSN Renewal Date" := TODAY;
            rMembershipCard."Allocated to Store" := Store;
            rMembershipCard."FSN SalesStaff" := SalesStaff;
            rMembershipCard."FSN TimeRenewalMembership" := TIME;
            rMembershipCard.VALIDATE(Status, rMembershipCard.Status::Active);
            rMembershipCard."Last Valid Date" := CALCDATE('<+1Y>', TODAY);
            rMembershipCard.MODIFY(TRUE);

            IF rMembersAccount.GET(rMembershipCard."Account No.") THEN BEGIN
                CLEAR(Customer2);
                IF Customer.GET(rMembersAccount."Linked To Customer No.") THEN BEGIN
                    Customer2 := Customer;
                    Customer2."Customer Disc. Group" := 'VIP';
                    Customer2.MODIFY(TRUE);
                END;
                rMembersAccount."Club Code" := 'VIP';
                rMembersAccount."Scheme Code" := 'VIP';
                rMembersAccount.MODIFY(TRUE);

            END;
        END;
    END;

    procedure ShowSpecificPanel()
    var
        FuncProfile_g: Record "LSC POS Func. Profile";
        Cliente_p: code[20];
    begin

        PosCtrl_g.ShowPanelModal('FSNINPUT');
    end;

    local procedure ValidManager(Manager: Boolean): Boolean
    begin
        if Manager then
            EXIT(TRUE)
        ELSE BEGIN
            ErrorText := Text002;
            EXIT(FALSE);
        END;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Controller", 'OnButtonPressed', '', true, true)]
    local procedure "LSC POS Controller_OnButtonPressed"
    (
        var POSMenuLine: Record "LSC POS Menu Line";
        var handled: Boolean
    )
    begin

        if PosMenuLine.Command = 'FSNPANELVIP' then begin
            IF MembershipCardConfirm(PosTransConfirt, text01) THEN BEGIN
                PosMenuLine.Command := 'TENDER_K';
                PosMenuLine.Parameter := '11';
                PosMenuLine."Parameter Type" := PosMenuLine."Parameter Type"::"Tender Type";
            END;
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
        Staff: Record "LSC Staff";
        permissionGroup: Record "LSC STAFF PER Group";
        PostransCU: Codeunit "LSC POS Transaction";
        Manager: Boolean;
        ltext001: Label 'This user is not a manager';
        Password: Text;
        pText: Text;
        SetNewStaffID: Text;
        StaffID: Text;
        WorkShift: Text;
        pReaseonText: Text[80];
    begin
        Clear(Manager);
        if (payload = 'LOGINMANAGERVIP') and (PanelID = '#FSNLOGIN') then begin
            if ResultOK then begin
                processed := true;
                Manager := true;
                StaffID := eposInterface.GetInputText(POSSession.StaffInputID);
                Password := eposInterface.GetInputText(POSSession.PasswordInputID);
                WorkShift := CopyStr(eposInterface.GetInputText(POSSession.WorkShiftInputID), 1, 1);
                if StaffID = '' then begin
                    exit;
                end;
                SetNewStaffID := StaffID;
                if not POSSession.Login(true, StaffID, Password, WorkShift, pReaseonText) then begin
                    POSGUI.PosMessage(pReaseonText);
                    exit;
                end;

                Staff.Reset();
                Staff.SETRANGE(ID, StaffID);
                if Staff.FindFirst() then begin
                    if permissionGroup.Get(Staff."Permission Group") then;
                    if permissionGroup."Manager Privileges" <> permissionGroup."Manager Privileges"::Yes then begin
                        POSGUI.PosMessage(ltext001);
                        exit;
                    end;
                end;
                Clear(StaffID);
                Clear(Password);
                Clear(WorkShift);
                PostransCU.TenderKeyPressed('11');
            end;
        end;
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
        POStrans: Record "LSC POS Transaction";
        POStransCU: Codeunit "LSC POS Transaction";
        inputVal: Decimal;
        lText001: Label 'Insufficient points';
        PaymentEntry: Record "LSC Trans. Payment Entry";
        Errotext: label 'No puede ingresar un dato mayor o menor a %1 NICOPUNTOS';
        POSExchangerateconversion: Codeunit "LSC POS Exch. rate conversion";
        AmountInCurrency: Decimal;
        Currency: Record Currency;
        Reodn: Decimal;
        menuLine: Record "LSC POS Menu Line";
        posTransCode: Codeunit "LSC POS Transaction";
    begin
        if (payload = '21') and resultOK then begin
            if POStrans.Get(POStransCU.GetReceiptNo()) then begin
                inputVal := 0;
                if Evaluate(inputVal, inputValue) then;
                if (POStrans."Starting Point Balance" < inputVal) and not POStrans."Sale Is Return Sale" then begin
                    POSGUI.PosMessage(lText001);
                    processed := true;
                    exit;
                end;
                IF POStrans."Sale Is Return Sale" THEN begin//VR27 -
                    PaymentEntry.Reset();
                    PaymentEntry.SetRange("Receipt No.", POStrans."Retrieved from Receipt No.");
                    PaymentEntry.SetRange(PaymentEntry."Tender Type", '11');
                    if PaymentEntry.FindFirst() then begin
                        Currency.get('NICOPUNTOS');
                        AmountInCurrency := Round(POSExchangerateconversion.POSExchangeLCYToFCY(POStrans."Trans. Date", 'NICOPUNTOS', inputVal) / POStrans."Currency Factor", Currency."Amount Rounding Precision");
                        Reodn := Round(POSExchangerateconversion.POSExchangeLCYToFCY(POStrans."Trans. Date", 'NICOPUNTOS', PaymentEntry."Amount Tendered") / POStrans."Currency Factor", Currency."Amount Rounding Precision");
                        if (Reodn <> inputVal) then
                            Error(StrSubstNo(Errotext, Reodn));
                        /*else
                            POStransCU.CalcTotals;*/
                    end;
                end else begin
                    POStrans."Starting Point Balance" := POStrans."Starting Point Balance" - inputVal;
                    POStrans.MODIFY();
                    menuLine.Command := 'CANCEL2';
                    posTransCode.run(menuLine);

                    POSSession.SetValue('CHANGEGRO', 'TRUE');
                    menuLine.Command := 'TOTAL';
                    posTransCode.run(menuLine);

                end;
            end;
        end;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Session", 'OnBeforeSetManagerID', '', true, true)]
    local procedure "LSC POS Session_OnBeforeSetManagerID"
    (
        Staff: Record "LSC Staff";
        var IsHandled: Boolean;
        var ReturnValue: Boolean
    )
    var
        POSCtrl: Codeunit "LSC POS Control Interface";
    begin
        if Staff."Permission Group" = 'MANAGER' then begin
            staffManager := true;
            //Message('Es Manager: ' + Staff.ID);
        end else begin
            staffManager := false;
            //Message('No Manager: ' + Staff.ID);
            PosContext_g.SetKeyValue('<#InfoText1>', '');
            PosCtrl_g.SendContext(PosContext_g);
        end;
        ValidManager(staffManager);
    end;


    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Transaction Events", 'OnAfterGetContext', '', true, true)]
    local procedure "LSC POS Transaction Events_OnAfterGetContext"
    (
        var POSTransaction: Record "LSC POS Transaction";
        var POSTransLine: Record "LSC POS Trans. Line";
        var CurrInput: Text
    )
    begin
        POSSession.SetValue('FSNMemberAccountPointBalance', GetMemberAccountPointBalance(POSTransaction));
        POSSession.SetValue('MemberCard_Trans', POSTransaction."Member Card No.");
    end;


    /*[EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Transaction Events", 'OnAfterStartNewTransaction', '', true, true)]
    local procedure "LSC POS Transaction Events_OnAfterStartNewTransaction"(var POSTransaction: Record "LSC POS Transaction")
    begin
        POSSession.SetValue('FSNMemberAccountPointBalance', GetMemberAccountPointBalance(POSTransaction));
    end;*/


    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Transaction Events", 'OnAfterTenderKeyExecuted', '', true, true)]
    local procedure "LSC POS Transaction Events_OnAfterTenderKeyExecuted"
    (
        var POSTransaction: Record "LSC POS Transaction";
        var POSTransLine: Record "LSC POS Trans. Line";
        var CurrInput: Text;
        var TenderTypeCode: Code[10]
    )
    var
        POSTransVIP: Codeunit "LSC POS Transaction";
        PaymentEntry: Record "LSC Trans. Payment Entry";
    begin
        if TenderTypeCode = '11' then begin
            IF POSTransaction."Sale Is Return Sale" THEN begin//VR27 - 
                PaymentEntry.Reset();
                PaymentEntry.SetRange("Receipt No.", POSTransaction."Retrieved from Receipt No.");
                PaymentEntry.SetRange(PaymentEntry."Tender Type", TenderTypeCode);
                if PaymentEntry.FindFirst() then
                    POSTransVIP.SetAmtAndBalance(PaymentEntry."Amount Tendered", PaymentEntry."Amount Tendered", PaymentEntry."Amount Tendered");
            end;//VR27 +
            POSTransVIP.CurrencyKeyPressed('NICOPUNTOS', 0);
            POSTransVIP.CalcTotals;//VR27 -+
        end;
    end;


    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Transaction Events", 'OnBeforeCheckMemberCard', '', true, true)]
    local procedure "LSC POS Transaction Events_OnBeforeCheckMemberCard"
    (
        var PosTransaction: Record "LSC POS Transaction";
        var MemberAccountTemp: Record "LSC Member Account";
        var MemberContactTemp: Record "LSC Member Contact";
        var MembershipCardTemp: Record "LSC Membership Card";
        var Handled: Boolean
    )
    var
        points: Decimal;
        pResponse: Text;
        pXMl: Text;
        FSNIntegrMember: Codeunit "FSN Integration Member";
        ErrorText: Label 'Cannot get points';
        MembershipCard: Record "LSC Membership Card";
    begin
        Commit();
        if MembershipCard.Get(MembershipCardTemp."Card No.") then;
        FSNIntegrMember.SetRequest(MembershipCard."Card No.", 'FSN_GETPOINTS');
        if FSNIntegrMember.Run() then begin
            FSNIntegrMember.GetResponse(pResponse, pXMl);
            if Evaluate(points, pResponse) then
                PosTransaction."Starting Point Balance" := points;
            MemberAccountTemp.TotalRemainingPointsInt := PosTransaction."Starting Point Balance";
        end else
            POSGUI.PosMessage(ErrorText);
    end;
}
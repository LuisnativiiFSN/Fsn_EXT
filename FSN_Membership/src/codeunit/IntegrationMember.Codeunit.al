/// <summary>
/// Codeunit FSN Integration Member (ID 50094).
/// </summary>
codeunit 50094 "FSN Integration Member"
{
    //* Interfaz para clientes VIP

    trigger OnRun()
    var
        xVip: Record "FSN IntegrationMember";
        xCod: Codeunit "FSN Loyalty";
        xGo: Boolean;
        MemberAccount: Record "LSC Member Account";
        MemberContact: Record "LSC Member Contact";
        MembershipCard: Record "LSC Membership Card";
        Cust: Record Customer;
        LinkCustTo: Code[20];
        MemberCardMgt: Codeunit "LSC Member Card Management";
        xDir1: Text[250];
        xDir2: Text[250];
        xVipMod: Record "FSN IntegrationMember";
    begin
        CASE gWSConfig OF
            'FSN_MEMBERCARD_REPLACE':
                MemberCardReplace(gRequest, gResponse);
            'FSN_GETPOINTS':
                GetPointsWithSP(gRequest, gResponse);
        END;
    end;

    var

        logger: Codeunit "LSC Debug Log";
        POSSession: Codeunit "LSC POS Session";

        _COMODIN: Label 'COMODIN';
        gText001: Label 'Error insert table %1 %2';
        gText002: Label 'Error modify table %1 %2';
        gText003: Label 'Value %1 not exists in table %2';
        gText004: Label 'Contact not exists %1 + %2';
        gRequest: Text;
        gResponse: Text;
        gWSConfig: Text[50];
        Membresia: code[20];
        Beneficiario: Text[100];

    procedure ProcessALLRecords()
    var
        MemberIntegration: Record "FSN IntegrationMember";
        MemberIntegration2: Record "FSN IntegrationMember";
        ErrorText: Text;
    begin
        CLEARLASTERROR();
        MemberIntegration.RESET;
        MemberIntegration.SETCURRENTKEY(Status);
        MemberIntegration.SETFILTER(MemberIntegration.Status, '<>%1', MemberIntegration.Status::Processed);
        IF MemberIntegration.FINDFIRST THEN
            REPEAT
                IF ProcessMemberRecord(MemberIntegration, ErrorText) THEN BEGIN
                    MemberIntegration2.GET(MemberIntegration.Card);
                    MemberIntegration2.Status := MemberIntegration2.Status::Processed;
                    MemberIntegration2."Process Message" := '';
                    MemberIntegration2."Date Processed" := TODAY;
                    MemberIntegration2."Time Processed" := TIME;
                    MemberIntegration2."User Process" := USERID;
                    IF MemberIntegration.Action = MemberIntegration.Action::Create THEN
                        MemberIntegration2."Date Create Card" := TODAY;
                    MemberIntegration2."Counter Process" += 1;
                    MemberIntegration2.MODIFY;
                END ELSE BEGIN
                    MemberIntegration2.GET(MemberIntegration.Card);
                    MemberIntegration2.Status := MemberIntegration2.Status::Error;
                    MemberIntegration2."Process Message" := COPYSTR(ErrorText, 1, 100);
                    MemberIntegration2.MODIFY;
                END;
                COMMIT;
            UNTIL MemberIntegration.NEXT = 0;
    end;

    procedure ProcessMemberRecord(pMemberIntegration: Record "FSN IntegrationMember"; var ErrorText: Text): Boolean
    var
        MemberClub_l: Record "LSC Member Club";
        MemberScheme_l: Record "LSC Member Scheme";
        MembershipCard_l: Record "LSC Membership Card";
        MemberAccount_l: Record "LSC Member Account";
        Customer_l: Record Customer;
        Store_l: Record "LSC Store";
        POSTerminal_l: Record "LSC POS Terminal";
        Staff_l: Record "LSC Staff";
        lText001: Label 'Value %1 not exists in table %2';
        lText002: Label 'Scheme %1 not exists in club %2';
        lText003: Label 'Action "Create". Member card %1 alredy exists';
        lText004: Label 'Action "Modify". Member card %1 not exists';
        lText005: Label 'Beneficiary cant is empty';
        lText006: Label 'Customer must be a personal document (DUI, NRC or Foreign Document)';
        lText007: Label 'Customer must be adult';
        lText008: Label 'Customer cant be "Retail Customer Group" COMODIN';
        MemberIntegration3: Record "FSN IntegrationMember";
        CustomerDiscountGroupCode: Code[20];
        CustomerPriceGroupCode: Code[10];
        IDSuggest: Code[20];
        lText009: Label 'Verify references is not used';
        DateFormulaValidateCard: DateFormula;
        lText010: Label 'Calc formula of "Card Expiration" is not valid in Table %1';
        lText011: Label 'Card must be expired for Action "Modify"';
        lText012: Label 'Customer cant be empty in table %1';
    begin

        ErrorText := '';

        IF MembershipCard_l.GET(pMemberIntegration.Card) AND (pMemberIntegration.Action = pMemberIntegration.Action::Create) THEN
            ErrorText := STRSUBSTNO(lText003, pMemberIntegration.Card)
        ELSE
            IF NOT MembershipCard_l.GET(pMemberIntegration.Card) AND (pMemberIntegration.Action = pMemberIntegration.Action::Renovate) THEN
                ErrorText := STRSUBSTNO(lText004, pMemberIntegration.Card)
            ELSE
                IF NOT MemberClub_l.GET(pMemberIntegration."Club Code") THEN
                    ErrorText := STRSUBSTNO(gText003, pMemberIntegration."Club Code", MemberClub_l.TABLECAPTION)
                ELSE
                    IF NOT MemberScheme_l.GET(pMemberIntegration."Scheme Code") THEN
                        ErrorText := STRSUBSTNO(gText003, pMemberIntegration."Scheme Code", MemberScheme_l.TABLECAPTION)
                    ELSE
                        IF NOT Store_l.GET(pMemberIntegration."Store No.") THEN
                            ErrorText := STRSUBSTNO(gText003, pMemberIntegration."Store No.", Store_l.TABLECAPTION)
                        /*
                        ELSE IF NOT POSTerminal_l.GET(pMemberIntegration."POS Terminal No.") THEN
                          ErrorText := STRSUBSTNO(gText003,pMemberIntegration."POS Terminal No.",POSTerminal_l.TABLECAPTION)
                        *///WVILLALTA14JUN19-+
                        ELSE
                            IF NOT Staff_l.GET(pMemberIntegration.StaffID) THEN
                                ErrorText := STRSUBSTNO(gText003, pMemberIntegration.StaffID, Staff_l.TABLECAPTION)
                            ELSE
                                IF NOT (pMemberIntegration.Beneficiary <> '') THEN
                                    ErrorText := lText005;

        /*IF ErrorText = '' THEN
            IF (MembershipCard_l."Last Valid Date" >= TODAY) AND (pMemberIntegration.Action = pMemberIntegration.Action::Renovate) THEN
                ErrorText := lText011;*/

        IF ErrorText = '' THEN
            IF (pMemberIntegration.Action = pMemberIntegration.Action::Renovate) THEN BEGIN
                IF MemberAccount_l.GET(MembershipCard_l."Account No.") THEN BEGIN
                    IF NOT Customer_l.GET(MemberAccount_l."Linked To Customer No.") THEN BEGIN
                        ErrorText := STRSUBSTNO(gText003, MemberAccount_l."Linked To Customer No.", Customer_l.TABLECAPTION);
                        EXIT(FALSE);
                    END;

                    IF MemberAccount_l."Linked To Customer No." = '' THEN
                        ErrorText := STRSUBSTNO(lText012, MemberAccount_l.TABLECAPTION)
                    ELSE
                        IF pMemberIntegration."Customer No." <> MemberAccount_l."Linked To Customer No." THEN BEGIN
                            MemberIntegration3.GET(pMemberIntegration.Card);
                            MemberIntegration3.VALIDATE("Customer No.", MemberAccount_l."Linked To Customer No.");
                            MemberIntegration3.MODIFY;
                        END;
                END ELSE
                    ErrorText := STRSUBSTNO(gText003, MemberAccount_l.TABLECAPTION);
            END ELSE
                IF (pMemberIntegration.Action = pMemberIntegration.Action::Create) THEN
                    IF NOT Customer_l.GET(pMemberIntegration."Customer No.") THEN
                        ErrorText := STRSUBSTNO(gText003, pMemberIntegration."Customer No.", Customer_l.TABLECAPTION);

        IF ErrorText = '' THEN
            IF NOT (FORMAT(MemberClub_l."Card Expiration") <> '') THEN
                ErrorText := STRSUBSTNO(lText010, MemberClub_l.TABLECAPTION);

        IF ErrorText = '' THEN BEGIN
            IF (Customer_l."FSN DUI" = '') AND (Customer_l."FSN NRC" = '') AND (Customer_l."FSN Foreign document" = '') THEN
                ErrorText := lText006
            ELSE
                IF Customer_l."FSN Birthday" <> 0D THEN BEGIN
                    IF CALCDATE('<+18Y>', Customer_l."FSN Birthday") > TODAY THEN
                        ErrorText := lText007;
                END ELSE
                    IF Customer_l."LSC Retail Customer Group" = _COMODIN THEN
                        ErrorText := lText008;
        END;

        IF (ErrorText <> '') THEN
            EXIT(FALSE);

        CustomerDiscountGroupCode := '';
        IF MemberScheme_l."Default Cust. Disc. Group" <> '' THEN
            CustomerDiscountGroupCode := MemberScheme_l."Default Cust. Disc. Group"
        ELSE
            IF MemberClub_l."Default Cust. Disc. Group" <> '' THEN
                CustomerDiscountGroupCode := MemberClub_l."Default Cust. Disc. Group"
            ELSE
                CustomerDiscountGroupCode := Customer_l."Customer Disc. Group";

        CustomerPriceGroupCode := '';
        IF MemberScheme_l."Default Price Group" <> '' THEN
            CustomerPriceGroupCode := MemberScheme_l."Default Price Group"
        ELSE
            IF MemberClub_l."Default Price Group" <> '' THEN
                CustomerPriceGroupCode := MemberClub_l."Default Price Group"
            ELSE
                CustomerPriceGroupCode := Customer_l."Customer Price Group";

        IDSuggest := '';
        IF Customer_l."FSN DUI" <> '' THEN
            IDSuggest := Customer_l."FSN DUI"
        ELSE
            IF Customer_l."FSN NRC" <> '' THEN
                IDSuggest := Customer_l."FSN NRC"
            ELSE
                IDSuggest := Customer_l."FSN Foreign document";

        IF pMemberIntegration.Action = pMemberIntegration.Action::Create THEN BEGIN
            IF NOT MemberMgtCard(1, pMemberIntegration.Card, MemberClub_l.Code, MemberScheme_l.Code, Customer_l."No.", Store_l."No.", IDSuggest,
              pMemberIntegration.Beneficiary, pMemberIntegration.StaffID, CustomerDiscountGroupCode, Customer_l.Name, CustomerPriceGroupCode,
              MemberClub_l."Card Expiration", ErrorText) THEN
                EXIT(FALSE);
        END ELSE
            IF pMemberIntegration.Action = pMemberIntegration.Action::Renovate THEN BEGIN
                IF NOT MemberMgtCard(2, pMemberIntegration.Card, MemberClub_l.Code, MemberScheme_l.Code, Customer_l."No.", Store_l."No.", IDSuggest,
                  pMemberIntegration.Beneficiary, pMemberIntegration.StaffID, CustomerDiscountGroupCode, Customer_l.Name, CustomerPriceGroupCode,
                  MemberClub_l."Card Expiration", ErrorText) THEN
                    EXIT(FALSE);
            END ELSE
                IF pMemberIntegration.Action = pMemberIntegration.Action::VerifyReferences THEN BEGIN
                    ErrorText := lText009;
                    EXIT(FALSE);
                END;

        EXIT(TRUE);

    end;

    procedure MemberMgtCard(pActionNo_: Integer; pCardNo_: Text[100]; pClubCode_: Code[10]; pSchemeCode_: Code[10]; pCustomer_: Code[20]; pStore: Code[10]; IDAccountSuggest_: Code[20]; pBeneficiario_: Text[100]; pStaff_: Code[20]; pCustomerDiscGroup: Code[20]; pCustomName: Text[50]; pPriceGroupClub: Code[10]; LastDateValidateCard: DateFormula; var ErrorText: Text): Boolean
    var
        CardAccount: Code[20];
        CardContact: Code[20];
        MemberCardNew: Record "LSC Membership Card";
        POSTerminal_l: Record "LSC POS Terminal";
        StoreCode_l: Code[10];
        MemberContact_l: Record "LSC Member Contact";
        lText001: Label 'Erro No. %1, %2';
        lText002: Label 'Contact not exists %1 + %2';
        lMemberCard: Record "LSC Membership Card";
    begin
        CardAccount := '';
        StoreCode_l := '';

        CardAccount := MemberMgtAccount(pActionNo_, pCustomer_, IDAccountSuggest_, pCustomerDiscGroup, pCardNo_, pCustomName, pClubCode_, pSchemeCode_, pPriceGroupClub, ErrorText);

        StoreCode_l := pStore;

        IF CardAccount <> '' THEN BEGIN
            CardContact := CardAccount;

            IF pActionNo_ = 1 THEN BEGIN
                MemberCardNew.INIT;
                MemberCardNew."Card No." := pCardNo_;
                MemberCardNew.Status := MemberCardNew.Status::Active;
                MemberCardNew."Linked to Account" := TRUE;
                MemberCardNew."Club Code" := pClubCode_;
                MemberCardNew."Scheme Code" := pSchemeCode_;
                //MemberCardNew."Account No." := CardAccount;
                //MemberCardNew."Contact No." := CardContact;
                MemberCardNew."Date Created" := TODAY;
                MemberCardNew."Created by" := USERID;
                MemberCardNew."Allocated to Store" := StoreCode_l;
                MemberCardNew."FSN Beneficiary" := pBeneficiario_;
                MemberCardNew."FSN SalesStaff" := pStaff_;
                MemberCardNew."FSN TimeRenewalMembership" := TIME;
                IF NOT MemberCardNew.INSERT(TRUE) THEN BEGIN
                    ErrorText := STRSUBSTNO(gText001, MemberCardNew.TABLECAPTION, GETLASTERRORTEXT);
                    EXIT(FALSE);
                END ELSE BEGIN
                    MemberCardNew."Account No." := CardAccount;
                    MemberCardNew."Contact No." := CardContact;
                    MemberCardNew."Scheme Code" := pSchemeCode_;
                    MemberCardNew."Last Valid Date" := CalcDate('<+1Y>', Today);
                    MemberCardNew.Status := MemberCardNew.Status::Active;
                    MemberCardNew."Linked to Account" := true;
                    IF NOT MemberCardNew.MODIFY(TRUE) THEN BEGIN
                        ErrorText := GETLASTERRORTEXT;
                        EXIT(FALSE);
                    END ELSE
                        EXIT(TRUE);
                END;
            END ELSE BEGIN
                IF NOT MemberContact_l.GET(CardAccount, CardContact) THEN BEGIN
                    ErrorText := STRSUBSTNO(gText002, CardAccount, CardContact);
                    EXIT(FALSE);
                END;
                IF NOT lMemberCard.GET(pCardNo_) THEN BEGIN
                    ErrorText := STRSUBSTNO(gText003, pCardNo_, lMemberCard.TABLECAPTION);
                    EXIT(FALSE);
                END;

                lMemberCard.Status := lMemberCard.Status::Active;
                lMemberCard."Linked to Account" := TRUE;
                lMemberCard."Club Code" := pClubCode_;
                lMemberCard."Scheme Code" := pSchemeCode_;
                lMemberCard."Last Valid Date" := CalcDate('<+1Y>', Today);//CALCDATE(LastDateValidateCard, Today);1601
                lMemberCard."Allocated to Store" := StoreCode_l;
                lMemberCard."FSN Beneficiary" := pBeneficiario_;
                lMemberCard."FSN Renewal Date" := TODAY;
                lMemberCard."FSN SalesStaff" := pStaff_;
                lMemberCard."FSN TimeRenewalMembership" := TIME;
                IF NOT lMemberCard.MODIFY(TRUE) THEN BEGIN
                    ErrorText := STRSUBSTNO(gText001, lMemberCard.TABLECAPTION, GETLASTERRORTEXT);
                    EXIT(FALSE);
                END ELSE
                    EXIT(TRUE);
            END;
        END ELSE BEGIN
            EXIT(FALSE);
        END;
    end;

    procedure MemberMgtCustomer(var ErrorText: Text; CustomerNo: Code[20]; CustomerDiscGroup: Code[20]): Boolean
    var
        lCustomer: Record Customer;
        lCustomerDiscGroup: Record "Customer Discount Group";
    begin
        lCustomer.LOCKTABLE;
        IF NOT lCustomer.GET(CustomerNo) THEN
            ErrorText := STRSUBSTNO(gText003, CustomerNo, lCustomer.TABLECAPTION);

        IF NOT lCustomerDiscGroup.GET(CustomerDiscGroup) THEN
            ErrorText := STRSUBSTNO(gText003, CustomerDiscGroup, lCustomerDiscGroup.TABLECAPTION);

        IF ErrorText = '' THEN
            IF CustomerDiscGroup <> lCustomer."Customer Disc. Group" THEN BEGIN
                lCustomer."Customer Disc. Group" := CustomerDiscGroup;
                IF NOT lCustomer.MODIFY(TRUE) THEN
                    ErrorText := STRSUBSTNO(gText001, lCustomer.TABLECAPTION, GETLASTERRORTEXT);
            END;

        EXIT(NOT (ErrorText <> ''));
    end;

    procedure MemberMgtAccount(pActionNo_l: Integer; pCustomer: Code[20]; pIDSuggest: Code[20]; pCustomerDisc: Code[20]; pCardModify: Text[100]; pCustName: Text[50]; pClubCode: Code[10]; pSchemeCode: Code[10]; pGroupPriceCub: Code[10]; var ErrorText: Text) _Code: Code[20]
    var
        MemberAccount_local: Record "LSC Member Account";
        MemberAccount2_l: Record "LSC Member Account";
        MemberAccountNew: Record "LSC Member Account";
        MemberContact2: Record "LSC Member Contact";
        lMemberCard: Record "LSC Membership Card";
        lMemberClub: Record "LSC Member Club";
        lText001: Label 'El cliente %1 no existe';
        lText002: Label 'Account alredy exists ID %1, is not match with Customer %2';
        lText003: Label 'Error de datos. No tiene cuentas membresia asociada a targeta %1.';
        lText004: Label 'El Cliente %1 no coincide con el de la Cuenta %2.';
    begin
        IF NOT MemberMgtCustomer(ErrorText, pCustomer, pCustomerDisc) THEN
            EXIT('');

        IF pActionNo_l = 2 THEN BEGIN
            IF NOT lMemberCard.GET(pCardModify) THEN
                ErrorText := STRSUBSTNO(gText003, pCardModify, lMemberCard.TABLECAPTION)
            ELSE
                IF NOT MemberAccount_local.GET(lMemberCard."Account No.") THEN
                    ErrorText := STRSUBSTNO(gText003, lMemberCard."Account No.", MemberAccount_local.TABLECAPTION)
                ELSE
                    IF NOT MemberContact2.GET(lMemberCard."Account No.", lMemberCard."Contact No.") THEN
                        ErrorText := STRSUBSTNO(gText004, lMemberCard."Account No.", lMemberCard."Contact No.")
                    ELSE
                        IF pCustomer <> MemberAccount_local."Linked To Customer No." THEN
                            ErrorText := STRSUBSTNO(lText004, pCustomer, MemberAccount_local."Linked To Customer No.")
                        ELSE
                            EXIT(lMemberCard."Account No.");

            IF ErrorText <> '' THEN
                EXIT('');
        END;

        MemberAccount_local.RESET;
        MemberAccount_local.SETRANGE(MemberAccount_local."Linked To Customer No.", pCustomer);
        IF NOT MemberAccount_local.FINDFIRST THEN BEGIN
            IF MemberAccount_local.GET(pIDSuggest) THEN
                IF MemberAccount2_l.GET(pCustomer) THEN BEGIN
                    ErrorText := STRSUBSTNO(lText002, pIDSuggest, pCustomer);
                    EXIT('');
                END ELSE
                    pIDSuggest := pCustomer;

            MemberAccountNew.INIT;
            MemberAccountNew."No." := pIDSuggest;
            MemberAccountNew.Status := MemberAccountNew.Status::Active;
            MemberAccountNew.Description := pCustName;
            MemberAccountNew."Linked To Customer No." := pCustomer;
            MemberAccountNew."Date Activated" := TODAY;
            MemberAccountNew.VALIDATE("Club Code", pClubCode);
            MemberAccountNew.VALIDATE("Scheme Code", pSchemeCode);
            MemberAccountNew."Price Group" := pGroupPriceCub;

            lMemberClub.Get(pClubCode);
            lMemberClub.TestField("Contact Handling", lMemberClub."Contact Handling"::"Contact same as Account");
            lMemberClub.TestField("Account No. Series");
            MemberAccountNew."No. Series" := lMemberClub."Account No. Series";
            MemberAccountNew."Club Code" := pClubCode;
            MemberAccountNew."Scheme Code" := pSchemeCode;
            IF NOT MemberAccountNew.INSERT(TRUE) THEN BEGIN
                ErrorText := STRSUBSTNO(gText001, MemberAccountNew.TABLECAPTION, GETLASTERRORTEXT);
                EXIT('');
            END ELSE BEGIN

                IF NOT MemberMgtContact(pIDSuggest, pIDSuggest, pCustomer, ErrorText) THEN
                    EXIT('')
                ELSE
                    EXIT(pIDSuggest);
            END;
        END ELSE
            EXIT(MemberAccount_local."No.");
    end;

    procedure MemberMgtContact(pKey1: Code[20]; pKey2: Code[20]; pCustomer: Code[20]; var ErrorText: Text): Boolean
    var
        MemberContact_Local: Record "LSC Member Contact";
        lText001: Label 'Cuenta no encontrada %1 %2';
        Customer_l: Record Customer;
    begin
        IF MemberContact_Local.GET(pKey1, pKey2) THEN BEGIN
            IF NOT Customer_l.GET(pCustomer) THEN BEGIN
                ErrorText := STRSUBSTNO(gText003, pCustomer, Customer_l.TABLECAPTION);
                EXIT(FALSE);
            END;

            MemberContact_Local.Name := Customer_l.Name;
            MemberContact_Local."Search Name" := Customer_l.Name;
            MemberContact_Local.Address := COPYSTR(Customer_l.Name, 1, MAXSTRLEN(MemberContact_Local.Address));
            MemberContact_Local."Phone No." := Customer_l."Phone No.";
            MemberContact_Local."No. Series" := 'R-STMT-S3';
            IF NOT MemberContact_Local.MODIFY(TRUE) THEN BEGIN  //IF NOT
                ErrorText := STRSUBSTNO(gText001, MemberContact_Local.TABLECAPTION, GETLASTERRORTEXT);
                EXIT(FALSE);
            END;
            EXIT(TRUE);
        END ELSE BEGIN
            ErrorText := STRSUBSTNO(gText003, pKey1, MemberContact_Local.TABLECAPTION);
            EXIT(FALSE);
        END;
    end;


    procedure MemberCardReplace(var pxmlRequest: Text; var pxmlResponse: Text)
    var
        Text001: Label 'Invalid value %1 in Request Node %2';
        Text101: Label '%1 %2 no existe';
        Text103: Label '%1 %2';
        Text106: Label 'Record %1 already exists. Value %2';
        ReqXml: XmlDocument;
        ResXml: XmlDocument;
        BodyNode: XmlNode;
        Node: XmlNode;
        LineNode: XmlNode;
        NodeList: XmlNodeList;
        RequestID: Text[30];
        RequestNodeList: array[3] of Text[50];
        ResponseNodeList: array[5] of Text[50];
        ParentNodeIndex: Integer;
        ParentNodeList: array[5] of Text[50];
        NodeName: Text[50];
        NodeBuffer: Record "LSC WS Node Buffer" temporary;
        ReqNodeList: Record "LSC WS Node Buffer" temporary;
        Response_Code: Code[30];
        Response_Text: Text[1024];
        UpdateAction: Text[30];
        AddOnly: Boolean;
        UpdateReplCounter: Boolean;
        ReplCounter: Integer;
        RecRefTemp: RecordRef;
        RecRef: RecordRef;
        MemberShipCard: Record "LSC Membership Card";
        MemberShipCardNew: Record "LSC Membership Card";
        FlowFieldBuffer: Record "LSC FlowField Buffer" temporary;
        UpdateFieldList: Record Field temporary;
        TableNodeList: Record "LSC WS Node Buffer" temporary;
        RecRefTemp2: array[32] of RecordRef;
        _Counter: Integer;
        Resp: Label 'No se pudo';
        cod: Label '51';
        NewCard: Text[100];
        OldCard: Text[100];
        LastDate: Date;
        DateText: Text[50];
        WSFunc: Codeunit "LSC WS Functions";
        gLocalProcess: Boolean;
    begin
        RequestID := 'FSN_MEMBERCARD_REPLACE';
        WSFunc.LoadRequest(pxmlRequest, ReqXml, RequestID, RequestNodeList, ResponseNodeList, ParentNodeIndex, ParentNodeList, BodyNode, Response_Code, Response_Text);

        LastDate := 0D;
        //Get List of request nodes
        //Get Tables - Nodes
        IF Response_Code = '0000' THEN
            WSFunc.AddChildNodeListText(RequestID, 0, ParentNodeIndex, ParentNodeList, 'CardNew', '',
              ReqNodeList, Response_Code, Response_Text);

        IF Response_Code = '0000' THEN
            WSFunc.AddChildNodeListText(RequestID, 0, ParentNodeIndex, ParentNodeList, 'CardOld', '',
              ReqNodeList, Response_Code, Response_Text);

        IF Response_Code = '0000' THEN
            WSFunc.AddChildNodeListText(RequestID, 0, ParentNodeIndex, ParentNodeList, 'LastDateCard', '',
              ReqNodeList, Response_Code, Response_Text);


        IF Response_Code = '0000' THEN
            WSFunc.GetChildNodeList(0, BodyNode, ReqNodeList, Response_Code, Response_Text);
        IF Response_Code = '0000' THEN BEGIN
            ReqNodeList.RESET;
            IF ReqNodeList.FIND('-') THEN
                REPEAT
                    CASE ReqNodeList.Source OF
                        'CardNew':
                            BEGIN
                                NewCard := ReqNodeList."Text Value";
                                IF NewCard = '' THEN BEGIN
                                    Response_Code := '0030';
                                    Response_Text := STRSUBSTNO(Text001, ReqNodeList."Text Value", ReqNodeList."Node Name");
                                END;
                            END;
                        'CardOld':
                            BEGIN
                                OldCard := ReqNodeList."Text Value";
                                IF OldCard = '' THEN BEGIN
                                    Response_Code := '0030';
                                    Response_Text := STRSUBSTNO(Text001, ReqNodeList."Text Value", ReqNodeList."Node Name");
                                END;
                            END;
                        'LastDateCard':
                            BEGIN
                                DateText := ReqNodeList."Text Value";
                                IF NOT EVALUATE(LastDate, DateText, 9) THEN;
                                /*IF LastDate = 0D THEN BEGIN
                                  Response_Code := '0030';
                                  Response_Text := STRSUBSTNO(Text001,ReqNodeList."Text Value",ReqNodeList."Node Name");
                                END;*/
                            END;
                    END;
                UNTIL (ReqNodeList.NEXT = 0) OR (Response_Code <> '0000');
        END;

        IF Response_Code <> '0000' THEN BEGIN
            WSFunc.ErrorResponse(RequestID, ResponseNodeList, Response_Code, Response_Text, gLocalProcess, pxmlResponse);
            EXIT;
        END;

        //Process Request
        IF MemberShipCard.GET(NewCard) THEN BEGIN
            Response_Code := '0102';
            Response_Text := STRSUBSTNO(Text106, MemberShipCard.TABLECAPTION, NewCard);
        END;
        IF Response_Code = '0000' THEN BEGIN
            IF NOT MemberShipCard.GET(OldCard) THEN BEGIN
                Response_Code := '0101';
                Response_Text := STRSUBSTNO(Text001, MemberShipCard.TABLECAPTION, OldCard);
            END ELSE BEGIN
                MemberShipCardNew.INIT();
                MemberShipCardNew := MemberShipCard;
                MemberShipCardNew."Card No." := NewCard;
                MemberShipCardNew."Date Created" := TODAY;
                IF LastDate <> 0D THEN
                    MemberShipCardNew."Last Valid Date" := LastDate;
                MemberShipCardNew.INSERT();
                MemberShipCardNew.MODIFY(TRUE);
                MemberShipCard.Status := MemberShipCard.Status::Blocked;
                MemberShipCard.MODIFY(TRUE);
            END;
        END;

        IF Response_Code <> '0000' THEN BEGIN
            WSFunc.ErrorResponse(RequestID, ResponseNodeList, Response_Code, Response_Text, gLocalProcess, pxmlResponse);
            EXIT;
        END;

        //Process Response Doc
        WSFunc.InitParentResNodeList(ResponseNodeList, ParentNodeIndex, ParentNodeList);

        //Respose Tables
        WSFunc.AddChildNodeTableList(RequestID, 1, ParentNodeIndex, ParentNodeList, 'LSC Membership Card', TableNodeList,
          Response_Code, Response_Text);
        IF Response_Code = '0000' THEN BEGIN
            IF TableNodeList.FINDLAST THEN;

            IF MemberShipCardNew.GET(NewCard) THEN BEGIN
                MemberShipCardNew.SETRECFILTER;
                RecRef.GETTABLE(MemberShipCardNew);
                RecRefTemp2[TableNodeList."Entry No."].OPEN(TableNodeList."Table No.", TRUE);
                WSFunc.CopyTableToTempTable(RecRef, RecRefTemp2[TableNodeList."Entry No."], FlowFieldBuffer);
            END ELSE BEGIN
                Response_Code := '1001';
                Response_Text := STRSUBSTNO(Text101, MemberShipCardNew.TABLECAPTION, STRSUBSTNO(Text103, NewCard, ''));
            END;
        END;

        IF Response_Code <> '0000' THEN BEGIN
            WSFunc.ErrorResponse(RequestID, ResponseNodeList, Response_Code, Response_Text, gLocalProcess, pxmlResponse);
            EXIT;
        END;

        //Response
        WSFunc.CreateResponse(ResXml, RequestID, ResponseNodeList, BodyNode);

        //Set Tables
        TableNodeList.RESET;
        IF TableNodeList.FIND('-') THEN
            REPEAT
                WSFunc.SetTableChildNodes(RequestID, 1, BodyNode, ParentNodeIndex, ParentNodeList, TableNodeList.Source,
                  RecRefTemp2[TableNodeList."Entry No."], FlowFieldBuffer, Response_Code, Response_Text);
            UNTIL (TableNodeList.NEXT = 0) OR (Response_Code <> '0000');

        IF Response_Code <> '0000' THEN BEGIN
            WSFunc.ErrorResponse(RequestID, ResponseNodeList, Response_Code, Response_Text, gLocalProcess, pxmlResponse);
            EXIT;
        END;
        ResXml.WriteTo(pxmlResponse);

    end;

    procedure SetRequest(pRequest: Text; pWSConfig: Text[50])
    begin
        gRequest := pRequest;
        gResponse := '';
        gWSConfig := pWSConfig;
    end;

    procedure GetResponse(var pXMLResponse: Text; var pXMLConfig: Text[50])
    begin
        pXMLResponse := gResponse;
        pXMLConfig := gWSConfig;
    end;

    local procedure GetPointsWithSP(MemberCardNo: Text[100]; var res: Text)
    var
        LSCRetailSetup: Record "LSC Retail Setup";
        PosFuncProfile: Record "LSC POS Func. Profile";
        LSCDistrnLoc: Record "LSC Distribution Location";
        spQuery: Label 'EXEC [Prefactura].[dbo].[sp_getMemberPointsByCard] ''%1''', Locked = true;
        SQLDataReader: DotNet SqlDataReader;
        SQLCommand: DotNet SqlCommand;
        SQLConnection: DotNet SqlConnection;
        SQLConnectionString: Text;
        SQLQuery: Text;
        points: Integer;
    begin
        //Validacion choca con cambio realizado para venta al credito
        //Si el cliente es TS Customer no se consultan puntos
        /*PosFuncProfile.RESET;
        IF PosFuncProfile.Get('#FASANI') THEN
            if PosFuncProfile."TS Customer" then begin*/

        //iniciar el logger
        logger.Init();
        logger.SetTerminal(POSSession.TerminalNo());
        logger.LogStartInfo();

        if not LSCRetailSetup.Get() then begin
            logger.LogError('LSC Retail Setup Not Found', 'CodeUnit(50095)::GetPointsWithSP');
            Points := '0';
        end;
        if not LSCDistrnLoc.Get(LSCRetailSetup."Distribution Location") then begin
            logger.LogError('LSC Distribution Location not found', 'CodeUnit(50095)::GetPointsWithSP');
            Points := '0';
        end;

        SQLConnectionString := 'Data Source=' + LSCDistrnLoc."Db Server Name" + ';Initial Catalog=' + LSCDistrnLoc."Db. Path && Name" + ';Integrated Security=false;User ID=' + LSCDistrnLoc."User ID" + ';Password=' + LSCDistrnLoc.Password;

        SQLQuery := StrSubstNo(spQuery, MemberCardNo);
        SQLConnection := SQLConnection.SqlConnection(SQLConnectionString);
        SQLConnection.Open();
        SQLCommand := SQLConnection.CreateCommand();
        SQLCommand.CommandText := SQLQuery;
        SQLDataReader := SQLCommand.ExecuteReader();
        if SQLDataReader.Read() then begin
            Points := SQLDataReader.GetInt32(0);
        end;
        SQLDataReader.Close();
        res := Format(Points);

    end;


    //Puntos dobles 
    [EventSubscriber(ObjectType::Table, Database::"LSC Member Point Setup", 'OnAfterInsertEvent', '', true, true)]
    local procedure "LSC Member Point Setup_OnAfterInsertEvent"
    (
        var Rec: Record "LSC Member Point Setup";
        RunTrigger: Boolean
    )
    var
        PosTransac: Record "LSC POS Transaction";
        POSTransC: Codeunit "LSC POS Transaction";
        Parameter: Record "FSN Parameter";
    begin
        if Rec.IsTemporary then begin
            if Parameter.Get('PUNTOS', 'DOBLES') and (Parameter.Activo) then
                if POStransac.Get(POSTransC.GetReceiptNo()) then begin
                    if (CopyStr(PosTransac."Receipt No.", 1, 10) = '00000APP01') OR
                        (CopyStr(PosTransac."Receipt No.", 1, 10) = '000PV#1000') then begin
                        Rec.Points := 2;
                        Rec.Modify();
                    end;
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
        member: Record "LSC Membership Card";
        Postransac: Record "LSC POS Transaction";
        FSNAff: page "FSN Affiliate MemberCard";
        Cust: Record Customer;
        PosTranLine: Record "LSC POS Trans. Line";
        POSTRANS: Codeunit "LSC POS Transaction";
    begin
        if POSMenuLine.Command = 'AFFILIATEMEMBER' then
            IF Postransac.Get(POSTRANS.GetReceiptNo()) then begin
                FSNAff.SETGLOBALVALUEP(Postransac);
                if member.Get(Postransac."Member Card No.") then begin
                    FSNAff.SETGLOBALVALUE(member);
                end else begin
                    if Cust.Get(Postransac."Customer No.") then begin
                        member.Reset();
                        IF Cust."FSN Customer Type" <> Cust."FSN Customer Type"::Company then begin
                            IF Cust."FSN DUI" <> '' then
                                member.SetRange("Account No.", Cust."FSN DUI")
                            else
                                member.SetRange("Account No.", Cust."FSN Foreign document");
                        end else
                            member.SetRange("Account No.", Cust."FSN NRC");
                        member.SetRange(Status, member.Status::Active);
                        member.SETFILTER(member."Last Valid Date", '>=%1', TODAY);
                        if member.FindFirst() then begin
                            FSNAff.SETGLOBALVALUE(member);
                        end else begin
                            member.SetFilter("Last Valid Date", '<=%1', Today);
                            if member.FindFirst() then begin
                                FSNAff.SETGLOBALVALUE(member);
                            end;
                        end;
                    end;
                end;
                PosTranLine.Reset();
                PosTranLine.SetRange("Receipt No.", Postransac."Receipt No.");
                PosTranLine.SetRange("Text Type", PosTranLine."Text Type"::"Cust. Text");
                if PosTranLine.Find('-') then
                    repeat
                        PosTranLine.Delete();
                    until PosTranLine.Next() = 0;

                Commit();
                FSNAff.RunModal();
            end;
    end;


    [EventSubscriber(ObjectType::Table, Database::"LSC Member Account Upgr. Entry", 'OnAfterInsertEvent', '', true, true)]
    local procedure "LSC Member Account Upgr. Entry_OnAfterInsertEvent"
    (
        var Rec: Record "LSC Member Account Upgr. Entry";
        RunTrigger: Boolean
    )

    var
        XMLRequest: Text;
        XMLResponse: Text;
        RequestID: Text[50];
        PosMenuLineTemp: Record "LSC POS Menu Line";
        Processed: Boolean;
        MsgResult: Text;
        FSNUtility: Codeunit "FSN Utility";
    begin
        if Rec."Expiration Date" = 0D then begin
            Rec."Expiration Date" := CalcDate('<+1Y>', Today);
            Rec.Modify();
        end;
    end;
    // end;


    //VR27-
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Transaction Events", 'OnAfterTenderKeyPressedEx', '', false, false)]
    local procedure OnAfterTenderKeyPressedEx(var POSTransaction: Record "LSC POS Transaction"; var POSTransLine: Record "LSC POS Trans. Line"; var CurrInput: Text; var TenderTypeCode: Code[10]; var TenderAmountText: Text; var IsHandled: Boolean);
    var
        msg: Text;
    begin
        if TenderTypeCode = '11' then
            IsHandled := not ValidateMemberCard(POSTransaction, msg);

        if IsHandled then
            Message(msg);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Transaction", 'OnBeforePostTransaction', '', false, false)]
    local procedure OnBeforePostTransaction(var Rec: Record "LSC POS Transaction");
    var
        transLine: Record "LSC POS Trans. Line";
        msg, tenderCode : Text;
    begin

        if Rec."Entry Status" = Rec."Entry Status"::Voided then
            exit;
        transLine.SetRange("Receipt No.", Rec."Receipt No.");
        transLine.SetRange("Store No.", Rec."Store No.");
        transLine.SetRange("POS Terminal No.", Rec."POS Terminal No.");
        transLine.SetRange("Entry Type", transLine."Entry Type"::Payment);
        transLine.SetRange("Entry Status", transLine."Entry Status"::" ");
        if transLine.FindFirst() then
            tenderCode := transLine.Number;
        if (rec."Starting Point Balance" <> 0) and (Rec."Customer Disc. Group" <> 'RETAIL') and (tenderCode = '11') then
            if not ValidateMemberCard(Rec, msg) then
                Error(msg);
    end;


    local procedure ValidateMemberCard(POSTrans: Record "LSC POS Transaction"; var ErrorText: Text): Boolean
    var
        memberCard: Record "LSC Membership Card";
        memberAccount: Record "LSC Member Account";
        customer: Record Customer;
        ERR000: Label 'BC: Tarjeta no existe';
        ERR001: Label 'BC: Cuenta Miembro no existe';
        ERR002: Label 'BC: Cliente no existe';
        ERR003: Label 'BC: Cliente no coincide con el de la cuenta';
    begin
        ErrorText := '';
        if not memberCard.GET(POSTrans."Member Card No.") then begin
            ErrorText := ERR000;
            exit(false);
        end;
        if not memberAccount.GET(memberCard."Account No.") then begin
            ErrorText := ERR001;
            exit(false);
        end;

        if not customer.GET(memberAccount."Linked To Customer No.") then begin
            ErrorText := ERR002;
            exit(false);
        end;

        if customer."No." <> POSTrans."Customer No." then begin
            ErrorText := ERR003;
            exit(false);
        end;

        exit(true);
    end;//VR27+


    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Transaction Events", 'OnBeforeTotalExecuted', '', true, true)]
    local procedure "LSC POS Transaction Events_OnBeforeTotalExecuted"
    (
        var POSTransaction: Record "LSC POS Transaction";
        var IsHandled: Boolean
    )
    begin
        if NOT IsHandled then
            IsHandled := VerifyMemberShitExist(POSTransaction);
    end;


    procedure VerifyMemberShitExist(VAR ValuePOSTransaction: Record "LSC POS Transaction"): Boolean
    var
        DeliveryOrder: Record "LSC Delivery Order";
        LSCPosTransLine: Record "LSC POS Trans. Line";
        MemberShipCard: Record "LSC Membership Card";
        ErrorText: Text;
        XMLRequest: Text;
        XMLResponse: Text;
        RequestID: Text[50];
        PosMenuLineTemp: Record "LSC POS Menu Line" temporary;
        Processed: Boolean;
        MsgResult: text;
        FSNUtility: Codeunit "FSN Utility";
        Membercard: Record "LSC Membership Card";
        FechaMasUnAño: Date;
    begin
        FechaMasUnAño := CalcDate('<+1Y>', Today);
        if not ValuePOSTransaction."Sale Is Return Sale" then begin
            RequestID := 'FSNCC';
            Processed := false;
            FSNUtility.InvokeGlobalChannel(XMLRequest, XMLResponse, RequestID, PosMenuLineTemp, Processed, MsgResult);
            If NOT Processed then begin
                if DeliveryOrder.Get(ValuePOSTransaction."Receipt No.") then begin
                    IF ValuePOSTransaction."Member Card No." <> '' THEN
                        if Membercard.Get(ValuePOSTransaction."Member Card No.") then begin
                            if Membercard."Last Valid Date" = FechaMasUnAño then
                                exit(false);
                        end;
                    ValidateMemb(ValuePOSTransaction);
                    LSCPosTransLine.Reset();
                    LSCPosTransLine.SetRange(LSCPosTransLine."Store No.", ValuePOSTransaction."Store No.");
                    LSCPosTransLine.SetRange(LSCPosTransLine."POS Terminal No.", ValuePOSTransaction."POS Terminal No.");
                    LSCPosTransLine.SetRange(LSCPosTransLine."Receipt No.", ValuePOSTransaction."Receipt No.");
                    LSCPosTransLine.SetRange(LSCPosTransLine."Entry Status", LSCPosTransLine."Entry Status"::" ");
                    LSCPosTransLine.SetRange(LSCPosTransLine."Entry Type", LSCPosTransLine."Entry Type"::Item);
                    LSCPosTransLine.SetFilter(LSCPosTransLine.Number, '=%1|%2', 'A7436', 'A6454');
                    if LSCPosTransLine.FindFirst() then begin
                        if LSCPosTransLine.Number = 'A7436' then
                            CreateNewMemberCard(ValuePOSTransaction, true)
                        else
                            CreateNewMemberCard(ValuePOSTransaction, false);
                        exit(True);
                    end;
                end;
            END;
        end;
        exit(false);
    end;

    procedure ValidateMemb(var POSTransactionTableRec: Record "LSC POS Transaction")
    var
        MemberCard, MemberCardV : Record "LSC Membership Card";
        MemberAccount: Record "LSC Member Account";
        Customer: Record Customer;
        InfocodeEntry: Record "LSC POS Trans. Infocode Entry";
        FechaMasUnAño: Date;
    begin
        FechaMasUnAño := CalcDate('<+1Y>', Today);
        if (CopyStr(POSTransactionTableRec."Receipt No.", 1, 10) = '00000APP01') OR
                       (CopyStr(POSTransactionTableRec."Receipt No.", 1, 10) = '00000APP02') OR
                           (CopyStr(POSTransactionTableRec."Receipt No.", 1, 10) = '000PV#1000') then begin

            InfocodeEntry.Reset();
            InfocodeEntry.SetRange("Receipt No.", POSTransactionTableRec."Receipt No.");
            InfocodeEntry.SetRange("Store No.", POSTransactionTableRec."Store No.");
            InfocodeEntry.SetRange("POS Terminal No.", POSTransactionTableRec."POS Terminal No.");
            InfocodeEntry.SetRange(Infocode, 'TEXT');
            InfocodeEntry.SetRange("Line No.", 44);
            if InfocodeEntry.FindFirst() then
                Membresia := InfocodeEntry."Information";

            InfocodeEntry.Reset();
            InfocodeEntry.SetRange("Receipt No.", POSTransactionTableRec."Receipt No.");
            InfocodeEntry.SetRange("Store No.", POSTransactionTableRec."Store No.");
            InfocodeEntry.SetRange("POS Terminal No.", POSTransactionTableRec."POS Terminal No.");
            InfocodeEntry.SetRange(Infocode, 'TEXT');
            InfocodeEntry.SetRange("Line No.", 43);
            if InfocodeEntry.FindFirst() then
                Beneficiario := InfocodeEntry."Information";

            if Beneficiario = '' then begin
                if Membresia <> '' then
                    if MemberCard.Get(Membresia) then begin
                        Beneficiario := MemberCard."FSN Beneficiary"
                    end else
                        Beneficiario := 'N/A';
            end;

            if Membresia <> '' then
                if POSTransactionTableRec."Member Card No." <> Membresia then
                    POSTransactionTableRec."Member Card No." := Membresia;
        end;
    end;

    procedure CreateNewMemberCard(VAR POSTransactionTableRec: Record "LSC POS Transaction"; process: Boolean)
    var
        FSNIntegrationMemberTab, FSNIntegrationMemberTabDelete : Record "FSN IntegrationMember";
        PosTransactionCod: Codeunit "LSC POS Transaction";
        ErrorText: Text;
        Text002: Label 'Error. %1';
        PgMemberIntegration: Page "FSN IntegrationMember";
        FiltCustomer: Record Customer;
        Customer_l: Record Customer;
        lText008: Label 'Customer cant be "Retail Customer Group" COMODIN';
        caption: Label 'Ingrese numero de tarjeta VIP y BENEFICIARIO';
        MembershipCard_l: Record "LSC Membership Card";
        Cust: Record Customer;
        menuLine: Record "LSC POS Menu Line";
        posTransC: Codeunit "LSC POS Transaction";
    begin
        FSNIntegrationMemberTabDelete.Reset();
        FSNIntegrationMemberTabDelete.SetRange(Status, FSNIntegrationMemberTabDelete.Status::Processed);
        if FSNIntegrationMemberTabDelete.FindSet() then
            repeat
                FSNIntegrationMemberTabDelete.Delete(false);
            until FSNIntegrationMemberTabDelete.Next() = 0;
        POSSession.SetValue('#MEMBERPROCESS', 'TRUE');
        Message(caption);

        if Customer_l.get(POSTransactionTableRec."Customer No.") then
            IF Customer_l."LSC Retail Customer Group" = _COMODIN THEN
                Error(lText008);

        FSNIntegrationMemberTab.Reset();
        FSNIntegrationMemberTab.SetRange(FSNIntegrationMemberTab."Receipt No.", POSTransactionTableRec."Receipt No.");
        if NOT FSNIntegrationMemberTab.FindFirst() then
            FSNIntegrationMemberTab.Card := POSTransactionTableRec."Member Card No.";

        IF FSNIntegrationMemberTab.Card = '' THEN BEGIN
            FSNIntegrationMemberTab.Card := Membresia;
            FSNIntegrationMemberTab.Beneficiary := Beneficiario;
        END;

        FSNIntegrationMemberTab."Receipt No." := POSTransactionTableRec."Receipt No.";
        FSNIntegrationMemberTab."Store No." := POSTransactionTableRec."Store No.";
        FSNIntegrationMemberTab."POS Terminal No." := POSTransactionTableRec."POS Terminal No.";
        FSNIntegrationMemberTab."Customer No." := POSTransactionTableRec."Customer No.";
        if FiltCustomer.get(POSTransactionTableRec."Customer No.") then
            FSNIntegrationMemberTab."Customer Name" := FiltCustomer.Name
        else
            FSNIntegrationMemberTab."Customer Name" := '';
        FSNIntegrationMemberTab.StaffID := POSTransactionTableRec."Staff ID";
        if process then
            FSNIntegrationMemberTab.Action := FSNIntegrationMemberTab.Action::Create
        else
            FSNIntegrationMemberTab.Action := FSNIntegrationMemberTab.Action::Renovate;
        FSNIntegrationMemberTab.Status := FSNIntegrationMemberTab.Status::Pending;
        FSNIntegrationMemberTab."Club Code" := 'VIP';
        FSNIntegrationMemberTab."Scheme Code" := 'VIP';
        FSNIntegrationMemberTab."Process Message" := '';
        FSNIntegrationMemberTab."Date Processed" := TODAY;
        FSNIntegrationMemberTab."Time Processed" := TIME;
        FSNIntegrationMemberTab."User Process" := USERID;
        FSNIntegrationMemberTab."Date Create Card" := TODAY;
        FSNIntegrationMemberTab."Counter Process" += 1;
        IF NOT FSNIntegrationMemberTab.Insert() THEN
            FSNIntegrationMemberTab.Modify();

        Commit();
        PgMemberIntegration.SetTableView(FSNIntegrationMemberTab);
        PgMemberIntegration.RunModal();
        PgMemberIntegration.GetRecord(FSNIntegrationMemberTab);

        FSNIntegrationMemberTab.Reset();
        FSNIntegrationMemberTab.SetRange(FSNIntegrationMemberTab."Receipt No.", POSTransactionTableRec."Receipt No.");
        FSNIntegrationMemberTab.SetFilter(Card, '<>%1', '');
        if FSNIntegrationMemberTab.FindFirst() then begin
            POSTransactionTableRec."Member Card No." := FSNIntegrationMemberTab.Card;
            POSTransactionTableRec.Modify(true);
        end;

        if FSNIntegrationMemberTab.Card <> '' then begin
            IF NOT ProcessMemberRecord(FSNIntegrationMemberTab, ErrorText) THEN BEGIN
                FSNIntegrationMemberTab.Reset();
                FSNIntegrationMemberTab.GET(POSTransactionTableRec."Member Card No.");
                FSNIntegrationMemberTab.Status := FSNIntegrationMemberTab.Status::Error;
                FSNIntegrationMemberTab."Process Message" := COPYSTR(ErrorText, 1, 100);
                FSNIntegrationMemberTab.MODIFY;
                POSTransactionTableRec."Member Card No." := '';
                POSTransactionTableRec.Modify(true);
                MESSAGE(STRSUBSTNO(Text002, ErrorText));
            END ELSE begin
                FSNIntegrationMemberTab.GET(POSTransactionTableRec."Member Card No.");
                FSNIntegrationMemberTab.Status := FSNIntegrationMemberTab.Status::Processed;
                FSNIntegrationMemberTab."Process Message" := '';
                FSNIntegrationMemberTab."Date Processed" := TODAY;
                FSNIntegrationMemberTab."Time Processed" := TIME;
                FSNIntegrationMemberTab."User Process" := USERID;
                IF FSNIntegrationMemberTab.Action = FSNIntegrationMemberTab.Action::Create THEN
                    FSNIntegrationMemberTab."Date Create Card" := TODAY;
                FSNIntegrationMemberTab."Counter Process" += 1;
                FSNIntegrationMemberTab.MODIFY;

                if POSTransactionTableRec."Member Card No." <> '' then begin
                    DeletCustomerL(POSTransactionTableRec);
                    ValidateGroupDesc(POSTransactionTableRec."Customer No.", POSTransactionTableRec."Member Card No.");
                    menuLine.Init();
                    menuLine.Command := 'MEMBERCARD';
                    menuLine.Parameter := POSTransactionTableRec."Member Card No.";
                    posTransC.run(menuLine);
                end

                /*if Cust.get(POSTransactionTableRec."Customer No.") then begin
                    POSTransactionTableRec."Customer Disc. Group" := Cust."Customer Disc. Group";
                    POSTransactionTableRec.Modify(true);
                end;*/
            end;
        end;

    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Transaction Events", 'OnAfterVoidPressed', '', true, true)]
    local procedure "LSC POS Transaction Events_OnAfterVoidPressed"(var POSTransaction: Record "LSC POS Transaction")
    var
        DeliveryOrder: Record "LSC Delivery Order";
        FSNIntnMemberTab: Record "FSN IntegrationMember";
        Label1: Label 'No puede anular transacion con Tarjeta VIP afiliada o Renovada %1';
    begin
        IF DeliveryOrder.Get(POSTransaction."Receipt No.") then begin
            FSNIntnMemberTab.Reset();
            FSNIntnMemberTab.SetRange(FSNIntnMemberTab."Receipt No.", POSTransaction."Receipt No.");
            FSNIntnMemberTab.SetFilter(FSNIntnMemberTab.Card, '<>%1', '');
            if FSNIntnMemberTab.FindFirst() then begin
                if FSNIntnMemberTab.Status = FSNIntnMemberTab.Status::Processed then
                    Error(StrSubstNo(Label1, FSNIntnMemberTab.Card))
                else
                    FSNIntnMemberTab.Delete();

            end;
        end;
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
}
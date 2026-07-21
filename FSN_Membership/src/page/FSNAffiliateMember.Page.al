page 50056 "FSN Affiliate MemberCard"
{
    Caption = 'Membresias';
    PageType = Card;
    UsageCategory = Lists;
    ApplicationArea = All;
    SourceTable = Customer;
    DeleteAllowed = false;
    InsertAllowed = false;

    layout
    {
        area(Content)
        {
            group(GroupName)
            {
                field("Customer No."; Cod_Clie)
                {
                    Editable = false;
                    ApplicationArea = All;
                }
                field("Customer Name"; Nom_Clie)
                {
                    Editable = false;
                    ApplicationArea = All;
                }
                field(Card; Tarj)
                {
                    ApplicationArea = All;
                    trigger OnValidate()
                    var
                        myInt: Integer;
                    begin
                        if MemberV.Get(Tarj) then begin
                            if MemberV."Account No." <> Afile then
                                Message(STRSUBSTNO(Mens01, Tarj, MemberV."Account No."));
                        end;
                    end;
                }
                field(Beneficiary; Beneficiario)
                {
                    ApplicationArea = All;
                }
                field("Last Valid Date"; Globals."Last Valid Date")
                {
                    Editable = false;
                    Visible = false;
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(Afiliar)
            {
                Promoted = true;
                ApplicationArea = All;
                PromotedIsBig = true;
                PromotedCategory = Process;
                trigger OnAction()
                begin
                    return := MemberManagement(Tarj, 'VIP', 'VIP', Cod_Clie, POSSession.TerminalNo(), Afile, Beneficiario, 1, POSSession.StaffID(), res, Code);
                    If Return then begin
                        Message(TexAf);
                        ValidateDiscCustomer();
                        itemC := 'A7436';
                    end else
                        Message(TexnAf);
                end;
            }

            action(Renovar)
            {
                Promoted = true;
                ApplicationArea = All;
                PromotedIsBig = true;
                PromotedCategory = Process;
                trigger OnAction()
                begin
                    return := MemberManagement(Tarj, 'VIP', 'VIP', Cod_Clie, POSSession.TerminalNo(), afile, Beneficiario, 2, POSSession.StaffID(), res, Code);
                    If Return then begin
                        Message(TexRenov);
                        ValidateDiscCustomer();
                        itemC := 'A6454';
                    end else
                        Message(TexRenov);
                end;
            }
        }
    }

    var
        myInt: Integer;
        Postransac: Record "LSC POS Transaction";
        POSSession: Codeunit "LSC POS Session";
        MemberAc: Record "LSC Member Account";
        Cod_Clie: Code[20];
        Nom_Clie: Text[50];
        Globals: Record "LSC Membership Card";
        gCustomer: Record Customer;
        _COMODIN: Label 'COMODIN';
        TexAf: Label 'Afiliacion exitosa';
        TexnAf: Label 'No se pudo afiliar tarjeta';
        TexRenov: Label 'Renovacion exitosa';
        TexNRenov: Label 'No se pudo renovar tarjeta';
        gMemberCard: Record "LSC Membership Card";
        gMemberClub: Record "LSC Member Club";
        gMemberScheme: Record "LSC Member Scheme";
        res: Text;
        Code: Text;
        Return: Boolean;
        Tarj: Code[20];
        Beneficiario: Text[100];
        Customer: Record Customer;
        VStaff: Code[10];
        UpgradeLogEntry: Record "LSC Member Account Upgr. Entry";
        Loyalti: Codeunit "FSN Loyalty";
        Validacion: Integer;
        itemC: Code[20];
        Afile: Code[20];
        MemberV: Record "LSC Membership Card";
        Mens01: Label 'TARJETA %1 PERTENECE A DUI %2';
        GlobalsPOST: Record "LSC POS Transaction";

    trigger OnOpenPage()
    var
        myInt: Integer;
        POSTRANS: Codeunit "LSC POS Transaction";
    begin
        if Globals."Card No." = '' then
            CardValidate(GlobalsPOST);
        if MemberAc.Get(Globals."Account No.") then begin
            Tarj := Globals."Card No.";
            Cod_Clie := MemberAc."Linked To Customer No.";
            Nom_Clie := MemberAc.Description;
            Beneficiario := Globals."FSN Beneficiary";
            ValidateCus(MemberAc."Linked To Customer No.");
            Afile := Globals."Account No.";
        end else begin
            IF Postransac.Get(POSTRANS.GetReceiptNo()) THEN begin
                IF Rec.Get(Postransac."Customer No.") then begin
                    if Rec."FSN Customer Type" <> Rec."FSN Customer Type"::Company then begin
                        Cod_Clie := Rec."No.";
                        Nom_Clie := Rec.Name;
                        if Rec."FSN DUI" <> '' then begin
                            Afile := Rec."FSN DUI";
                        end else
                            Afile := Rec."FSN Foreign document";
                    end else begin
                        Cod_Clie := Rec."No.";
                        Nom_Clie := Rec.Name;
                        Afile := Rec."FSN NRC";
                    end;
                    ValidateCus(Postransac."Customer No.");
                end;
            end;
        end;
    end;

    trigger OnClosePage()
    var
        myInt: Integer;
        POSTransaction: Record "LSC POS Transaction";
        POSTransCodeunit: Codeunit "LSC POS Transaction";
        PosTransLine: Record "LSC POS Trans. Line";
        Barc: Record "LSC Barcodes";
    begin
        IF itemC <> '' then begin
            if Globals."Card No." <> '' then begin
                POSTransCodeunit.InputMemberCard(Tarj);
            end else
                POSTransCodeunit.SelectCustPressed(Customer."No.");

            Barc.Reset();
            Barc.SetRange("Item No.", itemC);
            if Barc.FindFirst() then begin
                POSTransCodeunit.PluKeyPressed(Barc."Barcode No.");
            end;
        end else begin
            if Globals."Card No." <> '' then begin
                POSTransCodeunit.InputMemberCard(Tarj);
            end else
                POSTransCodeunit.SelectCustPressed(Customer."No.");
        end;
        Tarj := '';
        Cod_Clie := '';
        Nom_Clie := '';
        Beneficiario := '';
        Commit();
    end;

    procedure ValidateCus(CodCliente: code[20])
    var
        myInt: Integer;
        Messag: Label 'Fecha de nacimiento invalido';
    begin
        if Customer.get(CodCliente) then begin
            Rec := Customer;
            if format(Rec."FSN Birthday") = '' then
                Message(Messag);
        end;
    end;

    procedure SETGLOBALVALUE(MemberAccount: Record "LSC Membership Card")
    begin
        Globals := MemberAccount;
    end;

    procedure SETGLOBALVALUEP(PosTransaction: Record "LSC POS Transaction")
    begin
        GlobalsPOST := PosTransaction;
    end;

    procedure MemberManagement
    (
        pMemberCard: Text[100];
        pClubCode: Code[10];
        pSchemeCode: Code[10];
        pCustomerNo: Code[20];
        pPOSTerminalNo: Code[10];
        pIDAccountSuggest: Code[20];
        pBeneficiario: Text[100];
        pAction: integer;
        pStaff: Code[20];
        var Response_Code: Text[10];
        var Response_Text: Text
    ): Boolean
    var
        POSTerminal_l: Record "LSC POS Terminal";
        integrationMember: Codeunit "FSN integration Member";
        StoreCode_l: Code[10];
        lText001: Label 'Nada que hacer, acción ID = %1';
        lText002: Label 'El club %1 no existe';
        lText003: Label 'La tarjeta %1 aun esta vigente, vence el %2';
        lText004: Label 'El cliente debe ser mayor de Edad.';
        lText005: Label 'Cliente no existe %1';
        lText006: Label 'Fecha nacimiento no es correcta';
        lText007: Label 'El documento legal de cliente no puede esta vacio.';
        lText008: Label 'No se puede Afiliar / Renovar a un cliente COMODin';
        gText009: Label 'La tarjeta %1 ya existe';
        gText010: Label 'El beneficiario no puede estar vacio';
        gText011: Label 'El Club Membresia %1 no tiene configurado Periodo de expiración';
        gText001: Label 'No. %1 No existe en la Base Local (%2).';
        gText013: Label 'Tarjeta %1, en Club %2 dentro de esquema %3 fue registrada exitosamente!';
    begin
        Commit();
        //Action 1 = Crear, 2 = Renovar
        Response_Code := '0000';
        Response_Text := '';//STRSUBSTNO(lText001, ForMAT(pAction));
        if not (pAction in [1, 2]) then begin
            Response_Code := '0100';
            exit(false);
        end;

        Clear(POSTerminal_l);
        if POSTerminal_l.Get(pPOSTerminalNo) then
            StoreCode_l := POSTerminal_l."Store No.";

        if pIDAccountSuggest = '' then begin
            Response_Code := '0195';
            Response_Text := lText007;
            Message(lText007);
            exit(false);
        end;

        if not gCustomer.Get(pCustomerNo) then begin
            Response_Code := '0192';
            Response_Text := lText005;
            Message(lText005);
            exit(false);
        end;

        if (gCustomer."FSN DUI" <> '') or (gCustomer."FSN Foreign document" <> '') then begin
            if gCustomer."FSN Birthday" = 0D then begin
                Response_Code := '0194';
                Response_Text := lText006;
                Message(lText006);
                exit(false);
            end;

            if CALCDATE('<+18Y>', gCustomer."FSN Birthday") > TODAY then begin
                Response_Code := '0191';
                Response_Text := lText004;
                Message(lText004);
                exit(false);
            end;
        end;

        if gCustomer."LSC Retail Customer Group" = _COMODIN then begin
            Response_Code := '0196';
            Response_Text := lText008;
            Message(lText008);
            exit(false);
        end;

        if pBeneficiario = '' then begin
            Response_Code := '0190';
            Response_Text := gText010;
            Message(gText010);
            exit(false);
        end;

        if pAction = 2 then begin
            if not gMemberCard.Get(pMemberCard) then begin
                Response_Code := '0200';
                Response_Text := StrSubstNo(gText001, pMemberCard, gMemberCard.TABLECAPTION);
                Message(StrSubstNo(gText001, pMemberCard, gMemberCard.TABLECAPTION));
                exit(false);
            end;
        end else begin
            if gMemberCard.Get(pMemberCard) then begin
                Response_Code := '0205';
                Response_Text := StrSubstNo(gText009, pMemberCard);
                Message(StrSubstNo(gText009, pMemberCard));
                exit(false);
            end;
        end;

        if not gMemberClub.Get(pClubCode) then begin
            Response_Code := '0210';
            Response_Text := StrSubstNo(gText001, pClubCode, gMemberClub.TABLECAPTION);
            Message(StrSubstNo(gText001, pClubCode, gMemberClub.TABLECAPTION));
            exit(false);
        end else
            if Format(gMemberClub."Card Expiration") = ' ' then begin
                Response_Code := '0215';
                Response_Text := StrSubstNo(gText011, pClubCode);
                Message(StrSubstNo(gText011, pClubCode));
                exit(false);
            end;

        if not gMemberScheme.Get(pSchemeCode) then begin
            Response_Code := '0220';
            Response_Text := StrSubstNo(gText001, pSchemeCode, gMemberScheme.TABLECAPTION);
            Message(StrSubstNo(gText001, pSchemeCode, gMemberScheme.TABLECAPTION));
            exit(false);
        end;

        if not integrationMember.MemberMgtCard(pAction, pMemberCard, pClubCode, pSchemeCode, pCustomerNo, StoreCode_l, pIDAccountSuggest, pBeneficiario, pStaff, gCustomer."Customer Disc. Group", gCustomer.Name, gCustomer."Customer Price Group", gMemberClub."Card Expiration", Response_Text) then begin
            Response_Text := StrSubstNo(gText013, pMemberCard, pClubCode, pSchemeCode);
            Message(StrSubstNo(gText013, pMemberCard, pClubCode, pSchemeCode));
            exit(false);
        end;
        exit(true);
    end;

    procedure ValidateDiscCustomer()
    var
        myInt: Integer;
        rMembersAccount: Record "LSC Member Account";
        Customer2: Record Customer;
    begin
        IF rMembersAccount.GET(Afile) THEN BEGIN
            Customer2 := Customer;
            Customer2."Customer Disc. Group" := 'VIP';
            Customer2.MODIFY(TRUE);

            rMembersAccount."Club Code" := 'VIP';
            rMembersAccount."Scheme Code" := 'VIP';
            rMembersAccount.MODIFY(TRUE);
        end;
    end;

    procedure CardValidate(PosTrans: Record "LSC POS Transaction")
    var
        myInt: Integer;
        MembersAccount: Record "LSC Member Account";
        membercard: Record "LSC Membership Card";
    begin
        MembersAccount.Reset();
        MembersAccount.SetRange("Linked To Customer No.", PosTrans."Customer No.");
        if MembersAccount.FindFirst() then
            membercard.Reset();
        membercard.SetRange("Account No.", MembersAccount."No.");
        if membercard.FindLast() then begin
            Globals := membercard;
        end;
    end;
}
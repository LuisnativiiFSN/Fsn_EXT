/// <summary>
/// Page DTE POS Customer Card (ID 50096).
/// </summary>
page 50096 "DTE POS Customer Card"
{
    ApplicationArea = All;
    DeleteAllowed = false;
    Editable = true;
    InsertAllowed = false;
    PageType = Card;
    SourceTable = 18;
    UsageCategory = Administration;

    layout
    {
        area(Content)
        {
            group(CustomerCard)
            {
                Visible = isClientNormal;
                Editable = editableCustomer;
                grid(a)
                {
                    group(aa)
                    {
                        Caption = '';
                        field("No."; "No.")
                        {
                            ApplicationArea = All;
                            Editable = false;
                        }
                        field(Name; Name) { ApplicationArea = All; }
                        field("DTE Tax ID Type"; "DTE Tax ID Type")
                        {
                            ApplicationArea = All;
                            Caption = 'Doc. Tributario';
                        }
                        field("FSN DUI"; "FSN DUI") { ApplicationArea = All; }
                        field("FSN Foreign document"; "FSN Foreign document") { ApplicationArea = All; Caption = 'Doc. Extranjero'; }
                        field("VAT Registration No."; "VAT Registration No.")
                        {
                            ApplicationArea = All;
                            Caption = 'NIT';
                        }
                        field("E-Mail"; "E-Mail")
                        {
                            ApplicationArea = all;
                        }
                        field("FSN Birthday"; "FSN Birthday") { ApplicationArea = All; }
                        field("FSN Gender"; "FSN Gender") { ApplicationArea = All; }
                        field("Phone No."; "Phone No.") { ApplicationArea = All; }
                    }
                }
                grid(b)
                {
                    group(bb)
                    {
                        Caption = '';
                        field(Address; Address) { ApplicationArea = All; }
                        //field("Post Code"; "Post Code") { ApplicationArea = All; Caption = 'Cód.Municipio/Depto.'; }
                        field(Pais; Pais)
                        {
                            ApplicationArea = All;
                            Caption = 'País';
                            TableRelation = "Country/Region".Code;
                            trigger OnValidate()
                            var
                                countryCode, Country : Record "Country/Region";
                                PosTCode: Record "Post Code";
                            begin
                                Rec.Validate("Country/Region Code", Pais);
                                Rec.Modify(true);
                                if countryCode.Get(Pais) then begin
                                    Pais := countryCode.Name;
                                    PosTCode.Reset();
                                    PosTCode.SetRange("Country/Region Code", countryCode.Code);
                                    if PosTCode.Find('-') then begin
                                        PostCode_g := PosTCode.Code;
                                        Rec.Validate("Post Code", PosTCode.Code);
                                        Countys := Rec.County;
                                        Rec."Country/Region Code" := countryCode.Code;
                                        Rec.Modify(true);
                                    end else begin
                                        PosTCode.Reset();
                                        PosTCode.SetRange(code, '000');
                                        if PosTCode.Find('-') then begin
                                            PostCode_g := PosTCode.Code;
                                            Rec.Validate("Post Code", PosTCode.Code);
                                            Countys := Rec.County;
                                            Country.Reset();
                                            if Country.Get(countryCode.Code) then
                                                Rec."Country/Region Code" := Country.Code;
                                            Rec.Modify(true);
                                        end else
                                            PostCode_g := '';
                                    end;
                                end;
                            end;
                        }
                        field(PostCode_g; PostCode_g)
                        {
                            ApplicationArea = All;
                            Caption = 'Cód.Municipio/Depto.';
                            TableRelation = "Post Code".Code;
                            trigger OnValidate()
                            begin
                                PostCode.Reset();
                                PostCode.SetRange(Code, PostCode_g);
                                if PostCode.Find('-') then begin
                                    Rec.Validate("Post Code", PostCode_g);
                                    Countys := Rec.County;
                                    Rec.Modify(true);
                                    countryCode.SetRange(Code, postCode."Country/Region Code");
                                    if countryCode.FindFirst() then
                                        Pais := countryCode.Name
                                    else
                                        Pais := '';
                                end;
                            end;
                        }
                        field(Countys; Countys)
                        { ApplicationArea = All; Caption = 'County'; }



                        field("FSN NRC"; "FSN NRC") { ApplicationArea = All; }
                        field(Activity; Activity)
                        {
                            ApplicationArea = All;
                            Caption = 'Giro (Actividad economica)';
                            TableRelation = "DTE Parameter".Code where("Type" = const("Person Activity"));
                            trigger OnValidate()
                            var
                                DTEParam: Record "DTE Parameter";
                            begin
                                if not DTEParam.Get(DTEParam.Type::"Person Activity", Activity) then begin
                                    Rec."DTE Activity Code" := '';
                                    Rec."DTE Active Description" := '';
                                    Rec."FSN NRC Description" := '';
                                    Rec.Modify(true);
                                end else begin
                                    Rec."DTE Activity Code" := DTEParam.Code;
                                    Rec."DTE Active Description" := CopyStr(DTEParam.Description, 1, 250);
                                    Rec."FSN NRC Description" := CopyStr(DTEParam.Description, 1, 100);
                                    Rec.Modify(true);
                                end;

                            end;
                        }
                        field("FSN NRC Description"; "FSN NRC Description")
                        {
                            Caption = 'Giro (Anterior)';
                            Editable = false;
                            Enabled = false;
                        }
                        field("FSN Customer VAT Type"; "FSN Customer VAT Type") { ApplicationArea = All; }
                        field("VAT Bus. Posting Group"; "VAT Bus. Posting Group") { ApplicationArea = All; }
                        field("Customer Disc. Group"; "Customer Disc. Group") { ApplicationArea = All; Editable = false; }
                        field("FSN Customer Type"; "FSN Customer Type") { ApplicationArea = All; Caption = 'Tipo Cliente'; }
                    }
                }
            }
            group(SubCustomerCard)
            {
                Visible = isValidSubClient;
                Editable = editableSUBCustomer;
                Caption = 'Datos cliente secundario';
                field("FSN SubCustomerName"; subCustomer.Name)
                {
                    Caption = 'Nombre';
                    trigger OnValidate()
                    begin
                        subCustomer.Modify(true);
                    end;
                }
                field("FSN SubCustomerAddress"; subCustomer.Address)
                {
                    Caption = 'Dirección';
                    trigger OnValidate()
                    begin
                        subCustomer.Modify(true);
                    end;
                }
                field("FSN SubCustomerEmail"; subCustomer."E-Mail")
                {
                    Caption = 'Correo';
                    trigger OnValidate()
                    begin
                        subCustomer.Modify(true);
                    end;
                }
                field("FSN SubCustomerPhone"; subCustomer."Phone No.")
                {
                    Caption = 'Teléfono';
                    trigger OnValidate()
                    begin
                        subCustomer.Modify(true);
                    end;
                }
                field("FSN SubCustomerTaxIDType"; subCustomer."DTE Tax ID Type")
                {
                    Caption = 'Doc. Tributario';
                    trigger OnValidate()
                    begin
                        subCustomer.Modify(true);
                    end;
                }
                field("FSN SubCustomerDUI"; subCustomer."FSN DUI")
                {
                    Caption = 'DUI';
                    trigger OnValidate()
                    begin
                        subCustomer.Modify(true);
                    end;
                }
                field("FSN SubCustomerActivity"; subCustomer."DTE Activity Code")
                {
                    Caption = 'Giro';
                    trigger OnValidate()
                    begin
                        subCustomer.Modify(true);
                    end;
                }
                field("FSN SubCustomerNRC"; subCustomer."FSN NRC")
                {
                    Caption = 'NRC';
                    trigger OnValidate()
                    begin
                        subCustomer.Modify(true);
                    end;
                }
            }
            group(Beneficiary)
            {
                Caption = 'Datos beneficiario';
                Visible = showBeneficiaryField;
                field("FSN BeneficiaryName"; beneficiaryName)
                {
                    Caption = 'Nombre';
                }
            }
            group(ClientGeneric)
            {
                Caption = 'Datos Cliente Generico';
                Visible = isClientGeneric;
                field("FSN CLIENT GENERIC"; clientGenericName)
                {
                    Caption = 'Nombre';

                }
                field("FSN CLIENT EMAIL"; clientGenericEmail)
                {
                    Caption = 'Correo';

                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(getSubClient)
            {
                Visible = isValidSubClient;
                ApplicationArea = All;
                Caption = 'Agregar cliente secundario';
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;
                Image = AddContacts;
                trigger OnAction()
                begin
                    getSubClientFunc();
                end;
            }
            action(confirmSubClient)
            {
                Visible = isValidSubClient;
                ApplicationArea = All;
                Caption = 'Confirmar cliente secundario';
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;
                Image = Confirm;
                trigger OnAction()
                begin
                    if subCustomer.Name = '' then
                        Message('Debe ingresar un nombre para el cliente secundario')
                    else
                        confirmSubClientFunc();
                end;
            }
            action(addBeneficiary)
            {
                Visible = (not isValidSubClient) and (not isClientGeneric);
                ApplicationArea = All;
                Caption = 'Agregar beneficiario';
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;
                Image = AddContacts;
                trigger OnAction()
                begin
                    addBeneficiaryFunc();
                end;
            }
            action(addClientGeneric)
            {
                Visible = isClientGeneric;
                ApplicationArea = All;
                Caption = 'Agregar Cliente General';
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;
                Image = AddContacts;
                trigger OnAction()
                begin
                    ClientGenericSave(clientGenericName, clientGenericEmail);
                end;
            }

        }
    }

    trigger OnAfterGetRecord()
    begin
        Activity := Rec."DTE Activity Code";
        PostCode_g := Rec."Post Code";
        if countryCode.Get(Rec."Country/Region Code") then
            Pais := countryCode.Name;
    end;

    trigger OnOpenPage()
    var
        attribute: Record "LSC Attribute Value";
    begin
        if Rec.FindFirst() then;
        showBeneficiaryField := false;
        editableCustomer := isEditableCustomer(Rec);

        if Rec."LSC Retail Customer Group" = 'COMODIN' then begin
            showBeneficiaryField := false;
            isValidSubClient := false;
            isClientGeneric := true;
            isClientNormal := false;
        end else begin
            isValidSubClient := isSubClientEnabled(Rec);
            isClientNormal := true;
            isClientGeneric := false;
        end;


        if not editableCustomer then
            Message('El cliente no es editable');

        POSTransLine.Reset();
        POSTransLine.SetRange("Entry Status", 0);
        POSTransLine.SetRange("Entry Type", POSTransLine."Entry Type"::FreeText);
        POSTransLine.SetRange("Line No.", 41);
        POSTransLine.SetRange("Receipt No.", POSTransCodeunit.GetReceiptNo());
        if POSTransLine.Find('-') and (StrPos(POSTransLine.Description, 'BENEFICIARIO') > 0) then begin
            showBeneficiaryField := true;
            beneficiaryName := CopyStr(POSTransLine.Description, 15);
        end else begin
            attribute.SetRange("Attribute Code", 'CLIENTES');
            attribute.SetRange("Link Type", attribute."Link Type"::Customer);
            attribute.SetRange("Link Field 1", Rec."No.");
            attribute.SetRange("Attribute Value", 'SUB CLIENTE PV');
            IF NOT attribute.Find('-') AND not Rec."FSN Request Beneficiary" then
                showBeneficiaryField := true;
        end;
        infocodeGeneric.Reset();
        infocodeGeneric.SetRange("Line No.", 48);
        infocodeGeneric.SetRange("Receipt No.", POSTransCodeunit.GetReceiptNo());
        infocodeGeneric.SetRange("Transaction Type", 0);
        infocodeGeneric.SetRange(Information, 'TEXT');
        if infocodeGeneric.Find('-') then begin
            isClientGeneric := Rec."LSC Retail Customer Group" = 'COMODIN';
            isClientNormal := false;
            showBeneficiaryField := false;
            isValidSubClient := false;
            clientGenericName := infocodeGeneric.Information;
        end;
        infocodeGeneric.Reset();
        infocodeGeneric.SetRange("Line No.", 49);
        infocodeGeneric.SetRange("Receipt No.", POSTransCodeunit.GetReceiptNo());
        infocodeGeneric.SetRange("Transaction Type", 0);
        infocodeGeneric.SetRange(Information, 'TEXT');
        if infocodeGeneric.Find('-') then begin
            isClientGeneric := Rec."LSC Retail Customer Group" = 'COMODIN';
            isClientNormal := false;
            showBeneficiaryField := false;
            isValidSubClient := false;
            clientGenericEmail := infocodeGeneric.Information;
        end;


        POSInfocodeEntry.Reset();
        POSInfocodeEntry.SetRange("Receipt No.", POSTransCodeunit.GetReceiptNo());
        POSInfocodeEntry.SetRange("Line No.", 40);
        POSInfocodeEntry.SetRange(Infocode, 'TEXT');
        IF POSInfocodeEntry.Find('-') then
            if not subCustomer.Get(POSInfocodeEntry.Information) then
                Clear(subCustomer);

        if Rec."LSC Retail Customer Group" = 'COMODIN' then
            showBeneficiaryField := false;
    end;

    var
        #region tables.
        Countys: Text[30];
        subCustomer: Record Customer;
        PostCode: Record "Post Code";
        #endregion
        beneficiaryName: Text[86];
        editableCustomer, editableSUBCustomer : Boolean;
        countryCode: Record "Country/Region";
        subCustomerCode: Code[20];
        #region filters
        PostCode_g: Code[20];
        Pais: Code[50];
        Activity: Code[100];
        #endregion
        #region bands
        isValidSubClient, isClientGeneric, isClientNormal : Boolean;
        showBeneficiaryField: Boolean;
        #endregion
        POSInfocodeEntry, infocodeGeneric : Record "LSC POS Trans. Infocode Entry";
        POSTransLine: Record "LSC POS Trans. Line";
        POSTransCodeunit: Codeunit "LSC POS Transaction";

        clientGenericName, clientGenericEmail : Text[100];

    local procedure isEditableCustomer(Customer: Record Customer): Boolean
    var
        attribute: Record "LSC Attribute Value";
    begin
        attribute.SetRange("Attribute Code", 'CLIENTES');
        attribute.SetRange("Link Type", attribute."Link Type"::Customer);
        attribute.SetRange("Link Field 1", Customer."No.");
        attribute.SetRange("Attribute Value", 'NO EDITABLE');
        if attribute.FindSet() then
            exit(false);

        exit(true);
    end;

    local procedure addBeneficiaryFunc()
    var
        //infocode: Record "LSC POS Trans. Infocode Entry";
        transLine: Record "LSC POS Trans. Line";
        posTrans: Codeunit "LSC POS Transaction";
        session: Codeunit "LSC POS Session";
    begin
        case true of
            /* not showBeneficiaryField:
                 begin
                     beneficiaryName := '';
                     showBeneficiaryField := true;
                 end;*/
            (beneficiaryName = '') and showBeneficiaryField:
                begin
                    Message('Debe ingresar un nombre para el beneficiario');
                end;
            else begin
                transLine.Init();
                transLine."Store No." := session.StoreNo();
                transLine."POS Terminal No." := session.TerminalNo();
                transLine."Receipt No." := posTrans.GetReceiptNo();
                transLine."Line No." := 41;
                transLine."Entry Status" := transLine."Entry Status"::" ";
                transLine."Entry Type" := transLine."Entry Type"::FreeText;
                transLine.Description := 'BENEFICIARIO: ' + beneficiaryName;
                transLine."Quantity" := 1;
                if not transLine.Insert(true) then
                    transLine.Modify(true);

                Message('El beneficiario se ha agregado correctamente');

                //showBeneficiaryField := false;
            end;
        end;
    end;

    local procedure getSubClientFunc()
    var
        action: Action;
        session: Codeunit "LSC POS Session";
    begin
        action := Page.RunModal(Page::"DTE POS Customer", subCustomer);
        editableSUBCustomer := isEditableCustomer(subCustomer);
        IF subCustomer."LSC Retail Customer Group" = 'COMODIN' Then
            isClientGeneric := true;

    end;

    local procedure confirmSubClientFunc()
    begin
        subCustomer.Modify(true);

        saveSubClient();

        Message('EL CLIENTE SECUNDARIO SE HA AGREGADO CORRECTAMENTE');
    end;

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


    local procedure saveSubClient()
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
        infocode.Information := subCustomer."No.";
        infocode."POS Terminal No." := session.TerminalNo();
        infocode."Store No." := session.StoreNo();
        infocode.Date := Today();
        infocode.Time := Time();
        infocode."Staff ID" := session.StaffID();

        if not infocode.Insert(true) then
            infocode.Modify(true);
    end;

    local procedure ClientGenericSave(name: Text[100]; email: Text[100])
    var
        infocode: Record "LSC POS Trans. Infocode Entry";
        transLine: Record "LSC POS Trans. Line";
        posTransaction: Codeunit "LSC POS Transaction";
        session: Codeunit "LSC POS Session";
    begin

        case true of
            (name = '') and isClientGeneric:
                begin
                    Message('Debe ingresar un nombre para el cliente general');
                end;
            else begin
                infocode.Init();
                infocode."Receipt No." := posTransaction.GetReceiptNo();
                infocode."Transaction Type" := 0;
                infocode."Line No." := 48;
                infocode.Infocode := 'TEXT';
                infocode.Information := name;
                infocode."POS Terminal No." := session.TerminalNo();
                infocode."Store No." := session.StoreNo();
                infocode.Date := Today();
                infocode.Time := Time();
                infocode."Staff ID" := session.StaffID();

                if not infocode.Insert(true) then
                    infocode.Modify(true);

                infocode.Init();
                infocode."Receipt No." := posTransaction.GetReceiptNo();
                infocode."Transaction Type" := 0;
                infocode."Line No." := 49;
                infocode.Infocode := 'TEXT';
                infocode.Information := email;
                infocode."POS Terminal No." := session.TerminalNo();
                infocode."Store No." := session.StoreNo();
                infocode.Date := Today();
                infocode.Time := Time();
                infocode."Staff ID" := session.StaffID();

                if not infocode.Insert(true) then
                    infocode.Modify(true);
                /*
                transLine.Init();
                transLine."Store No." := session.StoreNo();
                transLine."POS Terminal No." := session.TerminalNo();
                transLine."Receipt No." := posTransaction.GetReceiptNo();
                transLine."Line No." := 50;
                transLine."Entry Status" := transLine."Entry Status"::" ";
                transLine."Entry Type" := transLine."Entry Type"::FreeText;
               
                transLine."Quantity" := 1;
                if transLine.Insert(true) then
                    transLine.Modify(true);
                */
                if name <> '' then begin
                    transLine.Reset();
                    transLine.SetRange("Receipt No.", posTransaction.GetReceiptNo());
                    transLine."Store No." := session.StoreNo();
                    transLine."POS Terminal No." := session.TerminalNo();
                    transLine.SetRange("Entry Type", transLine."Entry Type"::FreeText);
                    transLine.SetRange("Text Type", transLine."Text Type"::"Cust. Text");
                    if transLine.FindFirst then begin
                        transLine.Description := 'Clie: ' + name;
                        transLine.Modify(true);
                    end;
                end;

                transLine.Reset();
                transLine.SetRange("Receipt No.", posTransaction.GetReceiptNo());
                transLine.SetRange("POS Terminal No.", session.TerminalNo());
                transLine.SetRange("Entry Status", transLine."Entry Status"::" ");
                Message('El cliente general se ha agregado correctamente');
                CurrPage.Close();
            end;
        end;
    end;

    /*trigger OnInsertRecord()
    var
        NewCustomer: Record Customer;
        Customer: Record Customer;
        Err: Label 'No se puede crear cliente';
    begin
        //NewCustomer.Init();
        //if not Customer.Get(NewCustomer.CreateNewCustomer('',false)) then
        Error(Err);

    end;*/

}
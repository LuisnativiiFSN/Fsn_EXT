table 50050 "FSN Company Insurer"
{
    //WVILLALTA 10.21             - C/AL to AL

    Caption = 'Company Insurer';

    fields
    {
        field(10; "No."; Code[10])
        {
            Caption = 'No.';
        }
        field(20; "Customer No."; Code[20])
        {
            Caption = 'Customer No.';
            TableRelation = Customer."No." WHERE("FSN Insurer" = FILTER(true));

            trigger OnValidate()
            begin
                Description := '';
                if Customer.GET("Customer No.") then
                    Description := COPYSTR(Customer.Name, 1, MAXSTRLEN(Description));
            end;
        }
        field(30; Description; Text[100])
        {
            Caption = 'Description';
        }
        field(40; "Coinsurance No."; Code[10])
        {
            Caption = 'Coinsurance No.';

            TableRelation = "FSN Coinsurance"."No." WHERE("Customer Filter" = FIELD("Customer No."));
        }
        field(50; Comission; Decimal)
        {
            Caption = 'Comission';
            MinValue = 0;
        }
        field(60; Policy; Text[50])
        {
            Caption = 'Policy';
        }
        field(70; "Date Created"; Date)
        {
            Caption = 'Date Created';
            Editable = false;
        }
        field(80; "Created by User"; Code[50])
        {
            Caption = 'Created by User';
            Editable = false;
        }
        field(90; "Minimum Value"; Decimal)
        {
            Caption = 'Minimum Value';
        }
        field(100; "Maximum Value"; Decimal)
        {
            Caption = 'Maximum Value';
        }
        field(110; "Validate Recipe (Days)"; Integer)
        {
            Caption = 'Validate Recipe (Days)';
        }
        field(115; "Validate Auth No."; Enum "Validate Auth No Company")
        {
            Caption = 'Validate Auth No.';
        }
        field(120; "Validate Recipe"; Boolean)
        {
            Caption = 'Validate Recipe';
        }
        field(125; "Recipe By Line"; Boolean)
        {
            Caption = 'Recipe By Line';
        }
        field(130; "Send Maill"; Boolean)
        {
            Caption = 'Send Maill';
        }
        field(140; "Mail In Status"; Option)
        {
            Caption = 'Mail In Status';
            OptionCaption = 'Pending,Released,Coinsurance Invoiced,Close,Voided';
            OptionMembers = Pending,Released,"Coinsurance Invoiced",Close,Voided;
        }
        field(150; "Mail Address"; Text[80])
        {
            Caption = 'Mail Address';
            ExtendedDatatype = EMail;

            trigger OnValidate()
            var
                lText001: Label 'Apparently the email address is not correct, try another or verify the account';
            begin
            end;
        }
        field(160; Inactive; Boolean)
        {
            Caption = 'Inactive';
        }
        field(170; "Company Group"; Code[20])
        {
            Caption = 'Company Group';
            TableRelation = "FSN Company Group"."No.";
        }
        field(180; "User Filter Group for Cards"; Boolean)
        {
            Caption = 'User Filter Group for Cards';
        }
        field(190; "Bill Alone"; Boolean)
        {
            Caption = 'Bill Alone';
        }
        field(191; "Require Attachment Document"; Boolean)
        {
            Caption = 'Require Attachment Document';
        }
        field(200; "Price Formula"; Option)
        {
            Caption = 'Price Formula';
            OptionCaption = 'Standar,RoundExcVAT';
            OptionMembers = Standar,"Without Round";
        }
        field(50000; "Store No."; Code[20])
        {
            Caption = 'Store No.';
            TableRelation = "LSC Store"."No.";
        }
        field(50010; "Item No. Coinsurance"; Code[20])
        {
            Caption = 'Item No. Coinsurance';
            Description = 'Codigo a usar para facturar coaseguro';
            TableRelation = Item."No.";
        }
        field(50020; "Item No. Comission"; Code[20])
        {
            Caption = 'Item No. Comission';
            Description = 'Codigo a usar para facturar comision';
            TableRelation = Item."No.";
        }
        field(50030; "Item No. Deductible"; Code[20])
        {
            Caption = 'Item No. Deductible';
            Description = 'Codigo a usar para facturar Deducible';
            TableRelation = Item."No.";
        }
        field(50035; "Coinsurance Text Add"; Text[50])
        {
            Caption = 'Coinsurance Text Add';
        }
        field(50036; "Print Insured Links"; Option)
        {
            Caption = 'Print Insured Links';
            OptionCaption = 'None,ParentAndBeneficer';
            OptionMembers = "None",ParentAndBeneficer;
        }
        field(50040; "Pre Authorize Require"; Boolean)
        {
            Caption = 'Pre Authorize Require';
        }
        field(50050; "Authorize Require"; Boolean)
        {
            Caption = 'Authorize Require';
        }
        field(50060; "Print Date In Invoice"; Boolean)
        {
            Caption = 'Print Date In Invoice';
        }
        field(50070; "Coinsurance Manual"; Boolean)
        {
            Caption = 'Coinsurance Manual';
        }
        field(50080; "Deductible Manual"; Boolean)
        {
            Caption = 'Deductible Manual';
        }
        field(50085; "Invoiced In Status Released"; Boolean)
        {
            Caption = 'Invoiced In Status Released';
        }
        field(50090; "Lookup Coinsurance"; Code[20])
        {
            Caption = 'Lookup Coinsurance';
            TableRelation = "LSC POS Lookup"."Lookup ID";
        }
        field(50100; "Lookup Final Invoice"; Code[20])
        {
            Caption = 'Lookup Final Invoice';
            TableRelation = "LSC POS Lookup"."Lookup ID";
        }
        field(50101; "Usar Remision"; Boolean)
        {
        }
        field(50102; "Secondary Customer"; Boolean)
        {
            Caption = 'Secondary Customer';
        }
    }

    keys
    {
        key(Key1; "No.")
        {
            Clustered = true;
        }
        key(Key2; "Company Group", "User Filter Group for Cards")
        {
        }
    }

    fieldgroups
    {
        fieldgroup(DropDown; "No.", "Customer No.", Description, "Coinsurance No.", Inactive, "Store No.")
        {
        }
    }

    trigger OnDelete()
    begin
        CreateAction(2);
    end;

    trigger OnInsert()
    begin
        CreateAction(0);
        "Date Created" := TODAY;
        "Created by User" := USERID;
    end;

    trigger OnModify()
    begin
        CreateAction(1);
    end;

    trigger OnRename()
    begin
        CreateAction(3);
    end;

    var
        Customer: Record Customer;
        RetailSetup: Record "LSC Retail Setup";
        RetailUser: Record "LSC Retail User";
        Text000: Label '\-%1';
        Text001: Label 'If field "%1" is fill, field "%2" must be complete';
        Text002: Label 'Field "%1" is empty';
        Text003: Label 'Company "%1" is inactive';
        Text004: Label 'If field "%1" is fill, field "%2" must be empty';
        Text005: Label 'This company is assigned to store "%1"';
        ErrorText: Text;
        Text006: Label 'If field "%1" is not fill, field "%2" must be complete';
        Text007: Label 'Setup company is not correct. %1';


    procedure CreateAction(Type: Integer)
    var
        RecRef: RecordRef;
        xRecRef: RecordRef;
        ActionsMgt: Codeunit "LSC Actions Management";
    begin
        //LS
        //Type: 0 = INSERT, 1 = MODIFY, 2 = DELETE, 3 = RENAME
        //

        RecRef.GETTABLE(Rec);
        xRecRef.GETTABLE(xRec);
        ActionsMgt.SetCalledByTableTrigger(false);
        ActionsMgt.CreateActionsByRecRef(RecRef, xRecRef, Type);
        RecRef.CLOSE;
        xRecRef.CLOSE;
    end;

    procedure SearchOtherCompany(pNo: Code[10]; pCard: Code[20]): Code[10]
    var
        lCompany: Record "FSN Company Insurer";
        lCompany2: Record "FSN Company Insurer";
        lInsuredLink: Record "FSN Insured Links";
    begin
        lCompany.GET(pNo);

        Clear(RetailUser);
        if not RetailUser.Get(UserId) then
            RetailUser.Init();
        RetailSetup.GET();
        if RetailUser."Store No." <> '' then
            RetailSetup."Local Store No." := RetailUser."Store No.";

        IF (lCompany."Store No." = '') OR (RetailSetup."Local Store No." = lCompany."Store No.") THEN
            EXIT(lCompany."No.");

        IF (lCompany."Store No." <> '') AND (RetailSetup."Local Store No." <> lCompany."Store No.") THEN BEGIN
            IF (lCompany."User Filter Group for Cards") THEN BEGIN
                IF (lCompany."Company Group" = '') THEN
                    EXIT(pNo);
                lCompany2.RESET;
                lCompany2.SETCURRENTKEY("Company Group", "User Filter Group for Cards");
                lCompany2.SETRANGE(lCompany2."Company Group", lCompany."Company Group");
                lCompany2.SETFILTER(lCompany2."Store No.", '=%1|=%2', '', RetailSetup."Local Store No.");
                IF NOT lCompany2.FINDFIRST THEN
                    EXIT(pNo);
                REPEAT
                    IF (lCompany2."Store No." = RetailSetup."Local Store No.") OR (lCompany2."Store No." = '') THEN
                        EXIT(lCompany2."No.");
                UNTIL lCompany2.NEXT = 0;
            END;
        END;
        EXIT(pNo);
    end;


    procedure ValiateSetup(pCompanyNo: Code[10]; pInStore: Boolean; pStore: Code[10])
    var
        lCompany: Record "FSN Company Insurer";
    begin
        ErrorText := '';
        lCompany.GET(pCompanyNo);
        IF (lCompany."Coinsurance No." <> '') AND (lCompany."Lookup Coinsurance" = '') THEN
            ErrorText := STRSUBSTNO(Text000,
              STRSUBSTNO(Text001, lCompany.FIELDCAPTION(lCompany."Coinsurance No."), lCompany.FIELDCAPTION(lCompany."Lookup Coinsurance")));
        IF lCompany."Customer No." = '' THEN
            ErrorText += STRSUBSTNO(Text000,
              STRSUBSTNO(Text002, lCompany.FIELDCAPTION(lCompany."Customer No.")));
        IF lCompany.Inactive THEN
            ErrorText += STRSUBSTNO(Text000, STRSUBSTNO(Text003, lCompany.Description));

        IF lCompany."Invoiced In Status Released" THEN BEGIN
            IF lCompany."Coinsurance No." <> '' THEN
                ErrorText += STRSUBSTNO(Text000,
                  STRSUBSTNO(Text004, lCompany.FIELDCAPTION("Invoiced In Status Released"), lCompany.FIELDCAPTION(lCompany."Coinsurance No.")));
            IF lCompany.Comission <> 0 THEN
                ErrorText += STRSUBSTNO(Text000,
                  STRSUBSTNO(Text004, lCompany.FIELDCAPTION("Invoiced In Status Released"), lCompany.FIELDCAPTION(lCompany.Comission)));
            IF lCompany."Deductible Manual" THEN
                ErrorText += STRSUBSTNO(Text000,
                  STRSUBSTNO(Text004, lCompany.FIELDCAPTION("Invoiced In Status Released"), lCompany.FIELDCAPTION(lCompany."Deductible Manual")));
            IF lCompany."Lookup Coinsurance" <> '' THEN
                ErrorText += STRSUBSTNO(Text000,
                  STRSUBSTNO(Text004, lCompany.FIELDCAPTION("Invoiced In Status Released"), lCompany.FIELDCAPTION(lCompany."Lookup Coinsurance")));
        END;
        IF NOT lCompany."Invoiced In Status Released" THEN
            IF lCompany."Coinsurance No." = '' THEN
                ErrorText += STRSUBSTNO(Text000,
                  STRSUBSTNO(Text006, lCompany.FIELDCAPTION("Invoiced In Status Released"), lCompany.FIELDCAPTION(lCompany."Coinsurance No.")));
        IF (lCompany."Coinsurance No." <> '') AND (lCompany."Item No. Coinsurance" = '') THEN
            ErrorText += STRSUBSTNO(Text000,
              STRSUBSTNO(Text001, lCompany.FIELDCAPTION(lCompany."Coinsurance No."), lCompany.FIELDCAPTION(lCompany."Item No. Coinsurance")));
        IF (lCompany.Comission <> 0) AND (lCompany."Item No. Comission" = '') THEN
            ErrorText += STRSUBSTNO(Text000,
              STRSUBSTNO(Text001, lCompany.FIELDCAPTION(lCompany.Comission), lCompany.FIELDCAPTION(lCompany."Item No. Comission")));
        IF (lCompany."Deductible Manual") AND (lCompany."Item No. Deductible" = '') THEN
            ErrorText += STRSUBSTNO(Text000,
              STRSUBSTNO(Text001, lCompany.FIELDCAPTION(lCompany."Deductible Manual"), lCompany.FIELDCAPTION(lCompany."Item No. Deductible")));

        IF lCompany."Lookup Final Invoice" = '' THEN
            ErrorText += STRSUBSTNO(Text000, STRSUBSTNO(Text002, lCompany.FIELDCAPTION(lCompany."Lookup Final Invoice")));

        IF pInStore THEN
            IF lCompany."Store No." <> '' THEN BEGIN
                IF lCompany."Store No." <> pStore THEN
                    ErrorText += STRSUBSTNO(Text005, lCompany."Store No.");
            END;

        IF ErrorText <> '' THEN
            ERROR(STRSUBSTNO(Text007, ErrorText));
    end;

}


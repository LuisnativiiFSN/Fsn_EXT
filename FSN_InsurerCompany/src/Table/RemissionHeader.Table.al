table 50056 "FSN Remission Header"
{
    //WVILLALTA 10.21             - C/AL to AL

    Caption = 'Remission Header';

    fields
    {
        field(10; "Document Type"; Option)
        {
            Caption = 'Document Type';
            OptionMembers = Remission;
        }
        field(20; "No."; Code[20])
        {
            Caption = 'No.';
        }
        field(30; "Company No."; Code[20])
        {
            Caption = 'Company No.';
            TableRelation = "FSN Company Insurer"."No.";

            trigger OnValidate()
            begin
                IF xRec."Company No." <> "Company No." THEN BEGIN
                    RemissionLine.RESET;
                    RemissionLine.SETCURRENTKEY("Document Type", "Document No.", Type);
                    RemissionLine.SETRANGE(RemissionLine."Document Type", "Document Type");
                    RemissionLine.SETRANGE(RemissionLine."Document No.", "No.");
                    IF RemissionLine.FINDFIRST THEN
                        ERROR(Text006);
                END;
                "Comission Apply" := TRUE;

                "Customer Disc. Group" := '';
                "Price Group" := '';
                "Company Name" := '';
                "Customer No." := '';
                "Coinsurance No." := '';
                "Group Company No." := '';
                "Filter Card Groups" := FALSE;

                "Insured Card No." := '';
                "Insured Name" := '';
                "Insured Parent Card No." := '';
                "Insured Parent Name" := '';

                IF Companys.GET("Company No.") THEN BEGIN
                    Companys.ValiateSetup("Company No.", TRUE, "Store No.");
                    IF (Companys."Customer No." = '') OR
                      (Companys.Inactive) OR
                      (("Store No." <> Companys."Store No.") AND (Companys."Store No." <> '')) OR
                      ((NOT Companys."Invoiced In Status Released") AND (Companys."Item No. Coinsurance" = '')) OR
                      ((Companys.Comission <> 0) AND (Companys."Item No. Comission" = '')) OR
                      (Companys."Lookup Final Invoice" = '') THEN
                        ERROR(STRSUBSTNO(Text004, Companys.Description));

                    Customer.GET(Companys."Customer No.");
                    "Customer Disc. Group" := Customer."Customer Disc. Group";
                    "Price Group" := Customer."Customer Price Group";
                    "Company Name" := Companys.Description;
                    "Customer No." := Companys."Customer No.";
                    "Group Company No." := Companys."Company Group";
                    "Filter Card Groups" := Companys."User Filter Group for Cards";

                    IF Companys."Coinsurance No." <> '' THEN
                        VALIDATE("Coinsurance No.", Companys."Coinsurance No.");
                END;
            end;

        }
        field(40; "Customer No."; Code[20])
        {
            Caption = 'Customer No.';
            TableRelation = Customer."No.";
        }
        field(50; "Company Name"; Text[100])
        {
            Caption = 'Company Name';
        }
        field(60; Status; Option)
        {
            Caption = 'Status';
            OptionCaption = 'Pending,Released,Coinsurance Invoiced,Close,Voided,Exclude';
            OptionMembers = Pending,Released,"Coinsurance Invoiced",Close,Voided,Exclude;
        }
        field(70; "Create Date"; Date)
        {
            Caption = 'Create Date';
            Editable = false;
        }
        field(80; "Posting Date"; Date)
        {
            Caption = 'Posting Date';
            Editable = false;
        }
        field(90; "Store No."; Code[10])
        {
            Caption = 'Store No.';
            TableRelation = "LSC Store"."No.";
        }
        field(100; "POS Terminal No."; Code[10])
        {
            Caption = 'POS Terminal No.';
            TableRelation = "LSC POS Terminal"."No.";
        }
        field(110; "Customer Disc. Group"; Code[20])
        {
            Caption = 'Customer Disc. Group';
            TableRelation = "Customer Discount Group".Code;
        }
        field(115; "Price Group"; Code[10])
        {
            Caption = 'Price Group';
            TableRelation = "Customer Price Group".Code;
        }
        field(120; "Sales Staff"; Code[20])
        {
            Caption = 'Sales Staff';
            TableRelation = "LSC Staff".ID;

            trigger OnValidate()
            begin
                IF NOT Staff.GET("Sales Staff") THEN
                    ERROR(STRSUBSTNO(Text010, "Sales Staff"));
            end;
        }
        field(130; Amount; Decimal)
        {
            CalcFormula = Sum("FSN Remission Line".Amount WHERE("Document Type" = FIELD("Document Type"),
                                                             "Document No." = FIELD("No."),
                                                             Type = CONST(Item)));
            Caption = 'Amount';
            FieldClass = FlowField;
        }
        field(140; "Amount Including VAT"; Decimal)
        {
            CalcFormula = Sum("FSN Remission Line"."Amount Including VAT" WHERE("Document Type" = FIELD("Document Type"),
                                                                             "Document No." = FIELD("No."),
                                                                             Type = CONST(Item)));
            Caption = 'Amount Including VAT';
            FieldClass = FlowField;
        }
        field(150; "Document Date"; Date)
        {
            Caption = 'Document Date';
        }
        field(160; "External Document No."; Text[50])
        {
            Caption = 'External Document No.';
        }
        field(170; "No. Series"; Code[10])
        {
            Caption = 'No. Series';
            TableRelation = "No. Series".Code;
        }
        field(180; "Receipt No. Coinsurance"; Code[20])
        {
            Caption = 'Receipt No. Coinsurance';
            Editable = false;
        }
        field(190; "Receipt No. Closed"; Code[20])
        {
            Caption = 'Receipt No. Closed';
            Editable = false;
        }
        field(200; "POS Terminal No. Coinsurance"; Code[10])
        {
            Caption = 'POS Terminal No. Coinsurance';
            Editable = false;
            TableRelation = "LSC POS Terminal"."No.";
        }
        field(210; "POS Terminal No. Closed"; Code[10])
        {
            Caption = 'POS Terminal No. Closed';
            Editable = false;
            TableRelation = "LSC POS Terminal"."No.";
        }
        field(220; "Transaction No. Coinsurance"; Integer)
        {
            Caption = 'Transaction No. Coinsurance';
            Editable = false;
        }
        field(230; "Transaction No. Closed"; Integer)
        {
            Caption = 'Transaction No. Closed';
            Editable = false;
        }
        field(240; "Insured Card No."; Code[20])
        {
            Caption = 'Insured Card No.';
            TableRelation = IF ("Filter Card Groups" = CONST(false)) "FSN Insured Links".Card WHERE("Company No." = FIELD("Company No."))
            ELSE
            IF ("Filter Card Groups" = CONST(true)) "FSN Insured Links".Card;
            ValidateTableRelation = true;

            trigger OnValidate()
            var
                ExitInsuredGroup: Boolean;
            begin
                IF "Insured Card No." = '' THEN BEGIN
                    "Insured Name" := '';
                    Relation := 0;
                    "Insured Parent Card No." := '';
                    "Insured Parent Name" := '';
                    "Member Card No." := '';
                    EXIT;
                END;

                IF "Company No." = '' THEN
                    ERROR(Text003);

                "Insured Name" := '';
                Relation := 0;
                "Insured Parent Card No." := '';
                "Insured Parent Name" := '';
                "Member Card No." := '';

                ExitInsuredGroup := FALSE;
                IF "Filter Card Groups" THEN BEGIN
                    InsuranceLinks3.RESET;
                    InsuranceLinks3.SETRANGE(InsuranceLinks3.Card, "Insured Card No.");
                    IF NOT InsuranceLinks3.FINDFIRST THEN
                        ERROR(STRSUBSTNO(Text013, "Insured Card No."))
                    ELSE
                        REPEAT
                            IF InsuranceLinks3."Company No." <> '' THEN
                                ExitInsuredGroup := Companys2.GET(InsuranceLinks3."Company No.") AND (Companys2."Company Group" = "Group Company No.");
                        UNTIL (InsuranceLinks3.NEXT = 0) OR ExitInsuredGroup;

                    IF ExitInsuredGroup THEN
                        InsuranceLinks.GET(Companys2."No.", "Insured Card No.")
                    ELSE
                        ERROR(STRSUBSTNO(Text013, "Insured Card No."));
                END ELSE
                    InsuranceLinks.GET("Company No.", "Insured Card No.");

                IF InsuranceLinks.Inactive THEN
                    ERROR(STRSUBSTNO(Text011, "Insured Card No.", "Company No."));
                "Insured Name" := InsuranceLinks.Name;
                Relation := InsuranceLinks.Relation;
                IF Relation = Relation::Parent THEN BEGIN
                    "Insured Parent Card No." := "Insured Card No.";
                    "Insured Parent Name" := "Insured Name";
                END ELSE BEGIN
                    ;
                    InsuranceLinks2.GET(InsuranceLinks."Company No.", InsuranceLinks."Parent Card");
                    "Insured Parent Card No." := InsuranceLinks2.Card;
                    "Insured Parent Name" := InsuranceLinks2.Name;

                END;
            end;
        }
        field(250; "Insured Name"; Text[100])
        {
            Caption = 'Insured Name';
        }
        field(260; Relation; Option)
        {
            Caption = 'Relation';
            OptionCaption = 'Parent,Beneficiary';
            OptionMembers = Parent,Beneficiary;
        }
        field(270; "Insured Parent Card No."; Code[20])
        {
            Caption = 'Insured Parent Card No.';
        }
        field(280; "Insured Parent Name"; Text[100])
        {
            Caption = 'Insured Parent Name';
        }
        field(290; "Coinsurance No."; Code[10])
        {
            Caption = 'Coinsurance No.';
            TableRelation = "FSN Coinsurance"."No." WHERE("Customer Filter" = FIELD("Customer No."));

            trigger OnValidate()
            begin
                IF "Coinsurance No." <> '' THEN BEGIN

                    Companys.GET("Company No.");
                    Companys.TESTFIELD(Companys."Item No. Coinsurance");

                    Item.GET(Companys."Item No. Coinsurance");
                    Coinsurance.GET("Coinsurance No.");

                END ELSE BEGIN
                    RemissionLine.RESET;
                    RemissionLine.SETRANGE(RemissionLine."Document Type", "Document Type");
                    RemissionLine.SETRANGE(RemissionLine."Document No.", "No.");
                    RemissionLine.SETRANGE(RemissionLine.Type, RemissionLine.Type::Coinsurance);
                    RemissionLine.DELETEALL;
                END;
            end;

        }
        field(300; "Coinsurance Percent"; Decimal)
        {
            Caption = 'Coinsurance Percent';
        }
        field(310; "Coinsurance Value"; Decimal)
        {
            CalcFormula = Sum("FSN Remission Line"."Unit Price Inc. VAT" WHERE("Document Type" = FIELD("Document Type"),
                                                                            "Document No." = FIELD("No."),
                                                                            Type = FILTER(Coinsurance)));
            Caption = 'Coinsurance Value';
            FieldClass = FlowField;
        }
        field(320; "Document Total"; Decimal)
        {
            CalcFormula = Sum("FSN Remission Line"."Amount Including VAT" WHERE("Document Type" = FIELD("Document Type"),
                                                                             "Document No." = FIELD("No."),
                                                                             Type = CONST(Item)));
            Caption = 'Document Total';
            FieldClass = FlowField;
        }
        field(330; "Authorization No."; Text[30])
        {
            Caption = 'Authorization No.';
        }
        field(340; "Pre Authorization No."; Text[30])
        {
            Caption = 'Pre Authorization No.';
        }
        field(350; Comission; Decimal)
        {
            CalcFormula = Sum("FSN Remission Line"."Amount Including VAT" WHERE("Document Type" = FIELD("Document Type"),
                                                                             "Document No." = FIELD("No."),
                                                                             Type = CONST(Comission)));
            Caption = 'Comission';
            FieldClass = FlowField;
        }
        field(360; "Recipe Date"; Date)
        {
            Caption = 'Recipe Date';
        }
        field(370; "Deductible Amount"; Decimal)
        {
            CalcFormula = Sum("FSN Remission Line"."Amount Including VAT" WHERE(Type = CONST(Deductible),
                                                                             "Document Type" = FIELD("Document Type"),
                                                                             "Document No." = FIELD("No.")));
            Caption = 'Deductible Amount';
            FieldClass = FlowField;
        }
        field(375; "Deductible Manual"; Decimal)
        {
            Caption = 'Deductible Manual';
            Description = 'Temporary status Pending';
            MinValue = 0;

            trigger OnValidate()
            begin
                IF "Deductible Manual" <> 0 THEN BEGIN
                    Companys.GET("Company No.");
                    Companys.TESTFIELD(Companys."Item No. Deductible");

                    _Decimal := 0;
                    IF NOT Companys."Deductible Manual" THEN
                        ERROR(STRSUBSTNO(Text007, FORMAT(_Decimal)));

                    _Decimal := RemissionMgt.GetRemissionAmountIncVAT("Document Type", "No.");
                    IF "Deductible Manual" > _Decimal THEN
                        ERROR(STRSUBSTNO(Text007, FORMAT(_Decimal)));
                END;
            end;

        }
        field(380; "Member Card No."; Text[100])
        {
            Caption = 'Member Card No.';
        }
        field(390; "Create By User"; Code[50])
        {
            Caption = 'Create By User';
            Editable = false;
        }
        field(400; "Comission Apply"; Boolean)
        {
            Caption = 'Comission Apply';
        }
        field(410; Scanned; Boolean)
        {
            Caption = 'Scanned';
        }
        field(420; "VAT Amount"; Decimal)
        {
            Description = 'Use in POS Print Utility';
            Editable = false;
            FieldClass = Normal;
        }
        field(430; "Disc. Amount"; Decimal)
        {
            Description = 'Use in POS Print Utility';
            Editable = false;
        }
        field(440; "Group Company No."; Code[20])
        {
            Caption = 'Group Company No.';
            TableRelation = "FSN Company Group"."No.";
        }
        field(450; "Filter Card Groups"; Boolean)
        {
            Caption = 'Filter Card for Groups';
        }
        field(1002; "Replication Counter"; Integer)
        {

            trigger OnValidate()
            begin
                RemissionHeader.RESET;
                RemissionHeader.SETCURRENTKEY("Replication Counter");
                IF RemissionHeader.FINDLAST THEN
                    "Replication Counter" := RemissionHeader."Replication Counter" + 1
                ELSE
                    "Replication Counter" := 1;
            end;
        }
        field(1003; "auth Number"; Code[36])
        {
            Caption = 'auth Number';
        }
        field(1004; "Issued Date"; Date)
        {
            Caption = 'Issued Date';
        }
    }

    keys
    {
        key(Key1; "Document Type", "No.")
        {
            Clustered = true;
        }
        key(Key2; Status, "Sales Staff", "Create Date")
        {
        }
        key(Key3; "Company No.", "Customer No.", Status)
        {
        }
        key(Key4; "Replication Counter")
        {
        }
        key(Key5; "Store No.", "Receipt No. Coinsurance", "POS Terminal No. Closed", "Transaction No. Coinsurance")
        {
        }
        key(Key6; "Store No.", "Receipt No. Closed", "POS Terminal No. Closed", "Transaction No. Closed")
        {
        }
        key(Key7; "External Document No.")
        {
        }
    }

    fieldgroups
    {
        fieldgroup(DropDown; "No.", "Company Name", Status, "Create Date", "Sales Staff", "Insured Name")
        {
        }
    }

    trigger OnDelete()
    begin
        IF Status <> Status::Pending THEN
            ERROR(STRSUBSTNO(Text002, FORMAT(Status)));

        RemissionLine.RESET;
        RemissionLine.SETRANGE(RemissionLine."Document Type", "Document Type");
        RemissionLine.SETRANGE(RemissionLine."Document No.", "No.");
        RemissionLine.DELETEALL(TRUE);
        CreateAction(2);
    end;

    trigger OnInsert()
    var
        _Date: Date;
        _No: Code[20];
    begin
        Clear(RetailUser);
        if not RetailUser.Get(UserId) then
            RetailUser.Init();

        RetailSetup.GET;
        if RetailUser."Store No." <> '' then
            RetailSetup."Local Store No." := RetailUser."Store No.";

        /*
        RemissionHeader.RESET;
        RemissionHeader.SETCURRENTKEY(Status, "Sales Staff", "Create Date");
        RemissionHeader.SETRANGE(RemissionHeader.Status, RemissionHeader.Status::Pending);
        _Date := TODAY - 7;
        RemissionHeader.SETFILTER(RemissionHeader."Create Date", '<=%1', _Date);//Week
        IF RemissionHeader.FINDFIRST THEN BEGIN
            _No := RemissionHeader."No.";
            RemissionHeader.DELETE(TRUE);

            "Store No." := RetailSetup."Local Store No.";
            "No." := _No;
        END;
        *///Evaluate in Post Remission

        IF "No." = '' THEN BEGIN
            FasaniSetup.GET(RetailSetup."Local Store No.");
            "No." := SeriesManager.GetNextNo(FasaniSetup."No. Series Remission", TODAY, TRUE);
            "No. Series" := FasaniSetup."No. Series Remission";
            "Store No." := RetailSetup."Local Store No.";
        END;



        "Create Date" := TODAY;
        "Create By User" := USERID;
        "Document Date" := TODAY;

        CreateAction(0);
    end;

    trigger OnModify()
    var
        FSNCompanyInsurer: Record "FSN Company Insurer";
        pError: Boolean;
        pTextError: Text;
    begin

        IF FSNCompanyInsurer.Get(Rec."Company No.") AND (FSNCompanyInsurer.Policy <> 'CERRADO') THEN begin
            IF Status <> Status::Pending THEN
                ERROR(STRSUBSTNO(Text001, FORMAT(Status)));
        END;
        CreateAction(1);
    end;

    trigger OnRename()
    var
        FSNCompanyInsurer: Record "FSN Company Insurer";
        pError: Boolean;
        pTextError: Text;
    begin
        IF FSNCompanyInsurer.Get(Rec."Company No.") AND (FSNCompanyInsurer.Policy <> 'CERRADO') THEN begin
            IF Status <> Status::Pending THEN
                ERROR(STRSUBSTNO(Text001, FORMAT(Status)));
        END;
        CreateAction(3);
    end;

    var
        FasaniSetup: Record "FSN Fasani Setup";
        SeriesManager: Codeunit NoSeriesManagement;
        Companys: Record "FSN Company Insurer";
        Companys2: Record "FSN Company Insurer";
        RetailSetup: Record "LSC Retail Setup";
        RetailUser: Record "LSC Retail User";
        InsuranceLinks: Record "FSN Insured Links";
        InsuranceLinks2: Record "FSN Insured Links";
        InsuranceLinks3: Record "FSN Insured Links";
        Coinsurance: Record "FSN Coinsurance";
        RemissionLine: Record "FSN Remission Line";
        Customer: Record Customer;
        Staff: Record "LSC Staff";
        Store: Record "LSC Store";
        POSFuncProfile: Record "LSC POS Func. Profile";
        Item: Record Item;
        RemissionMgt: Codeunit "FSN Remission Mgt.";
        _Decimal: Decimal;
        RemissionHeader: Record "FSN Remission Header";
        Text001: Label 'Not allowed modify in status %1';
        Text002: Label 'Not allowed delete in status %1';
        Text003: Label 'Company undefined';
        Text004: Label 'Company %1 is not configured or be inactive';
        Text006: Label 'Can´t change Company because line details exists';
        Text007: Label 'Deductible cant be Higher to $%1';
        Text010: Label 'Sales staff %1 not exists';
        Text011: Label 'Card %1 from Company %2 is inactive';
        Text013: Label 'Card %1 not exists';
    //Text014: Label 'Have a remission %1 in status pending from Customer %1'


    procedure Initialize()
    begin
        TESTFIELD("Store No.");
        Store.GET("Store No.");
        POSFuncProfile.GET(Store."Functionality Profile");
    end;


    procedure ModifyTrigger()
    begin
        CreateAction(1);
        VALIDATE("Replication Counter");
        CreateRequestMail(Rec);
    end;


    procedure ModifyLinesPOSCoinsurance()
    begin
        RemissionLine.RESET;
        RemissionLine.SETRANGE(RemissionLine."Document Type", "Document Type");
        RemissionLine.SETRANGE(RemissionLine."Document No.", "No.");
        IF RemissionLine.FINDFIRST THEN
            REPEAT
                RemissionLine."Receipt No. Coinsurance" := "Receipt No. Coinsurance";
                RemissionLine."POS Terminal No. Coinsurance" := "POS Terminal No. Coinsurance";
                RemissionLine."Transaction No. Coinsurance" := "Transaction No. Coinsurance";
                RemissionLine.MODIFY(TRUE);
            UNTIL RemissionLine.NEXT = 0;
    end;


    procedure ModifyLinesPOSClose()
    begin
        RemissionLine.RESET;
        RemissionLine.SETRANGE(RemissionLine."Document Type", "Document Type");
        RemissionLine.SETRANGE(RemissionLine."Document No.", "No.");
        IF RemissionLine.FINDFIRST THEN
            REPEAT
                RemissionLine."Receipt No. Closed" := "Receipt No. Closed";
                RemissionLine."POS Terminal No. Closed" := "POS Terminal No. Closed";
                RemissionLine."Transaction No. Closed" := "Transaction No. Closed";
                RemissionLine.MODIFY(TRUE);
            UNTIL RemissionLine.NEXT = 0;
    end;


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


    procedure CreateRequestMail(lRemissionHeader: Record "FSN Remission Header")
    /*var
        _Ok: Boolean;
        _SearchAddress: Text[80];
        _Receipt: Code[20];
        lMailRegister: Record "Mail Register";
        lCompany: Record "Company Insurer";
        lCoinsurance: Record Coinsurance;*/
    begin

        /*_Ok := FALSE;
        _SearchAddress := '';
        IF (lRemissionHeader."Company No." <> '') AND (lCompany.GET(lRemissionHeader."Company No.")) THEN
            IF lCompany."Send Maill" AND (lCompany."Mail In Status" = lRemissionHeader.Status) THEN BEGIN
                Customer.GET(lRemissionHeader."Customer No.");
                Store.GET(lRemissionHeader."Store No.");
                IF lCoinsurance.GET(lRemissionHeader."Coinsurance No.") THEN
                    IF lCoinsurance."Mail Address" <> '' THEN
                        _SearchAddress := lCoinsurance."Mail Address";
                IF _SearchAddress = '' THEN
                    _SearchAddress := lCompany."Mail Address";
                _Ok := _SearchAddress <> '';

                lMailRegister.RESET;
                lMailRegister.SETCURRENTKEY("Table Origin", "Key Code", "Key Integer");
                lMailRegister.SETRANGE(lMailRegister."Table Origin", DATABASE::"Remission Header");
                lMailRegister.SETRANGE(lMailRegister."Key Code", lRemissionHeader."No.");
                lMailRegister.SETRANGE(lMailRegister."Key Integer", lRemissionHeader."Document Type");
                IF NOT lMailRegister.FINDFIRST THEN BEGIN
                    lMailRegister.INIT();
                    lMailRegister."Table Origin" := DATABASE::"Remission Header";
                    lMailRegister."Key Code" := lRemissionHeader."No.";
                    IF lRemissionHeader.Status = lRemissionHeader.Status::"Coinsurance Invoiced" THEN
                        lMailRegister."Key Code 1" := lRemissionHeader."Receipt No. Coinsurance"
                    ELSE
                        lMailRegister."Key Code 1" := lRemissionHeader."Receipt No. Closed";
                    lMailRegister."Key Integer" := lRemissionHeader."Document Type";
                    lMailRegister."Key Integer 1" := lRemissionHeader.Status;
                    lMailRegister."To Address" := _SearchAddress;
                    lMailRegister."Copy-to Address" := '';
                    lMailRegister."Subject Line" := COPYSTR(STRSUBSTNO(Text008, Customer.Name, lRemissionHeader."Company Name",
                          Store.Name, lRemissionHeader."External Document No."), 1, 250);
                    lMailRegister."Attachment Filename" := '';
                    lMailRegister."Sending Date" := 0D;
                    lMailRegister."Sending Time" := 0T;
                    lMailRegister."Document Type" := lMailRegister."Document Type"::Sale;
                    lMailRegister."External Document No." := '';
                    IF NOT _Ok THEN BEGIN
                        lMailRegister.Status := lMailRegister.Status::Error;
                        lMailRegister."Error Type" := lMailRegister."Error Type"::"Invalid Email";
                        lMailRegister."Error Send Description" := Text009;
                    END ELSE BEGIN
                        lMailRegister.Status := lMailRegister.Status::Open;
                        lMailRegister."Error Type" := 0;
                        lMailRegister."Error Send Description" := '';
                    END;
                    lMailRegister.INSERT(TRUE);
                END ELSE BEGIN
                    _Receipt := '';
                    CASE lRemissionHeader.Status OF
                        lRemissionHeader.Status::"Coinsurance Invoiced":
                            _Receipt := lRemissionHeader."Receipt No. Coinsurance";
                        lRemissionHeader.Status::Close:
                            _Receipt := lRemissionHeader."Receipt No. Closed";
                    END;

                    IF lMailRegister.Status = lMailRegister.Status::Open THEN BEGIN
                        IF (_Receipt <> '') AND (lMailRegister."Key Integer 1" <> 3) THEN
                            lMailRegister."Key Code 1" := _Receipt;
                        IF _Ok AND (lMailRegister."To Address" = '') THEN BEGIN
                            lMailRegister."To Address" := _SearchAddress;
                            lMailRegister."Error Send Description" := '';
                        END;
                        lMailRegister.MODIFY(TRUE);
                    END;
                END;
            END ELSE
                IF lCompany."Send Maill" THEN
                    IF lRemissionHeader.Status = lRemissionHeader.Status::Close THEN BEGIN
                        lMailRegister.RESET;
                        lMailRegister.SETCURRENTKEY("Table Origin", "Key Code", "Key Integer");
                        lMailRegister.SETRANGE(lMailRegister."Table Origin", DATABASE::"Remission Header");
                        lMailRegister.SETRANGE(lMailRegister."Key Code", "No.");
                        lMailRegister.SETRANGE(lMailRegister."Key Integer", "Document Type");
                        IF lMailRegister.FINDFIRST THEN BEGIN
                            IF lRemissionHeader."Receipt No. Closed" <> '' THEN
                                lMailRegister."Key Code 1" := lRemissionHeader."Receipt No. Closed";
                            lMailRegister."Key Integer 1" := lRemissionHeader.Status;
                            lMailRegister.MODIFY(TRUE);
                        END
                    END;
        *///Suscription FSN_Email
    end;

    procedure PostRemission(var Remission: Record "FSN Remission Header"; var pError: Boolean; var pTextError: Text)
    var
        lCompany: Record "FSN Company Insurer";
        lRemissionLine: Record "FSN Remission Line";
        lInsuredLink: Record "FSN Insured Links";
        Remision_l: Record "FSN Remission Header";
        FSNParameter_l: record "FSN Parameter";
        i: Integer;
        _Date: Date;
        FSNCompanyInsurer: Record "FSN Company Insurer";
        RemissionMgt: Codeunit "FSN Remission Mgt.";
        Text005: Label 'Company %1 is not configured for %2';
        Text015: Label 'Remission cant be higher to $%1 . According Setup company';
        Text016: Label 'Remission cant be less to $%1. According setup Company';
    begin
        pError := FALSE;
        pTextError := '';
        IF Remission.Status <> Remission.Status::Pending THEN BEGIN
            pError := TRUE;
            pTextError := STRSUBSTNO(Text002, FORMAT(Remission.Status));
        END;

        pError := FALSE;
        pTextError := '';
        RemissionMgt.verifyValidation(Remission, pError, pTextError);
        IF pError THEN
            ERROR(pTextError);

        //Test week document
        i := 0;
        Remision_l.RESET;
        Remision_l.SETCURRENTKEY(Status, "Sales Staff", "Create Date");
        Remision_l.SETRANGE(Remision_l.Status, Remision_l.Status::Pending);
        if FSNParameter_l.Get('REMISSION', 'LASTDATE') then
            if Evaluate(i, FSNParameter_l.Valor) then
                if i > 0 then begin
                    _Date := TODAY - i;
                    Remision_l.SETFILTER(Remision_l."Create Date", '<=%1', _Date);
                    IF Remision_l.Find('-') AND (Remision_l."Create Date" > _Date) THEN BEGIN
                        //pError := TRUE;
                        //pTextError := STRSUBSTNO(Text017, RemissionHeader."No.", RemissionHeader."Create Date");
                        //_No := RemissionHeader."No.";
                        Remision_l.DELETEALL(TRUE);
                        /*"Store No." := RetailSetup."Local Store No.";
                        "No." := _No;*/
                    END;
                end;

        /*IF "No." = '' THEN BEGIN
            FasaniSetup.GET(RetailSetup."Local Store No.");
            "No." := SeriesManager.GetNextNo(FasaniSetup."No. Series Remission", TODAY, TRUE);
            "No. Series" := FasaniSetup."No. Series Remission";
            "Store No." := RetailSetup."Local Store No.";
            
        END;*/

        IF Remission."External Document No." = '' THEN
            pTextError := STRSUBSTNO(Text003, Remission.FIELDCAPTION("External Document No."));

        IF Remission."Sales Staff" = '' THEN
            pTextError := STRSUBSTNO(Text003, Remission.FIELDCAPTION("Sales Staff"));


        IF NOT lCompany.GET(Remission."Company No.") THEN
            pTextError := STRSUBSTNO(Text004, lCompany.TABLECAPTION, Remission."Company No.");

        IF lCompany."Maximum Value" > 0 THEN
            IF RemissionMgt.GetRemissionAmountIncVAT(Remission."Document Type", Remission."No.") > lCompany."Maximum Value" THEN
                pTextError := STRSUBSTNO(Text015, FORMAT(lCompany."Maximum Value"));

        IF lCompany."Minimum Value" > 0 THEN
            IF RemissionMgt.GetRemissionAmountIncVAT(Remission."Document Type", Remission."No.") < lCompany."Minimum Value" THEN
                ERROR(STRSUBSTNO(Text016, FORMAT(lCompany."Minimum Value")));

        IF lCompany."Pre Authorize Require" AND (Remission."Pre Authorization No." = '') THEN
            pTextError := STRSUBSTNO(Text003, Remission.FIELDCAPTION("Pre Authorization No."));

        IF lCompany."Authorize Require" AND (Remission."Authorization No." = '') THEN
            pTextError := STRSUBSTNO(Text003, Remission.FIELDCAPTION("Authorization No."));

        IF NOT lCompany."Deductible Manual" AND (Remission."Deductible Manual" <> 0) THEN
            pTextError := STRSUBSTNO(Text005, lCompany."No.", Remission.FIELDCAPTION("Deductible Manual"));

        IF Remission."Deductible Manual" <> 0 THEN
            Remission.VALIDATE("Deductible Manual");

        Remission.VALIDATE("Insured Card No.");

        IF (lCompany."Item No. Deductible" = '') AND (Remission."Deductible Manual" <> 0) THEN
            pTextError := STRSUBSTNO(Text005, lCompany."No.", Remission.FIELDCAPTION("Deductible Manual"));

        IF (lCompany."Coinsurance No." <> Remission."Coinsurance No.") AND NOT lCompany."Coinsurance Manual" THEN
            pTextError := STRSUBSTNO(Text005, lCompany."No.", lCompany.FIELDCAPTION("Coinsurance Manual"));

        IF (lCompany.Comission <> 0) AND (lCompany."Item No. Comission" = '') THEN
            pTextError := STRSUBSTNO(Text005, lCompany."No.", lCompany.FIELDCAPTION(Comission));

        IF pTextError = '' THEN BEGIN
            lRemissionLine.RESET;
            lRemissionLine.SETRANGE(lRemissionLine."Document Type", Remission."Document Type");
            lRemissionLine.SETRANGE(lRemissionLine."Document No.", Remission."No.");
            lRemissionLine.SETRANGE(lRemissionLine.Type, lRemissionLine.Type::Item);
            IF NOT lRemissionLine.FINDFIRST THEN
                pTextError := Text006
            ELSE
                REPEAT
                    IF lRemissionLine.Quantity = 0 THEN BEGIN
                        pTextError := STRSUBSTNO(Text007, lRemissionLine.Description);
                        pError := TRUE;
                    END;
                    lRemissionLine.VALIDATE(lRemissionLine."Replication Counter");
                    lRemissionLine.MODIFY;
                UNTIL (lRemissionLine.NEXT = 0) OR pError;
        END;

        pError := pTextError <> '';
        IF pError THEN
            EXIT;

        IF FSNCompanyInsurer.Get(Remission."Company No.") AND (FSNCompanyInsurer.Policy = 'CERRADO') THEN begin
            Remission.Status := Remission.Status::Exclude;
            exit;
        end;
    end;

}


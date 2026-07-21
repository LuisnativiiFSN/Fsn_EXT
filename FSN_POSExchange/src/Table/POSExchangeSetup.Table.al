table 50067 "FSN POS Exchange Setup"
{

    Caption = 'FSN POS Exchange Setup';

    fields
    {
        field(10; "No."; Code[20])
        {
        }
        field(11; "POS Exchange Code"; Code[20])
        {
            Caption = 'POS Exchange Code';
        }
        field(20; Description; Text[50])
        {
            Caption = 'Description';
        }
        field(30; "Quantity Sale"; Decimal)
        {
            Caption = 'Quantity Sale';
            DecimalPlaces = 0 : 0;
        }
        field(40; "Quantity Gift"; Decimal)
        {
            Caption = 'Quantity Gift';
            DecimalPlaces = 0 : 0;
        }
        field(50; "Starting Date"; Date)
        {
            Caption = 'Starting Date';

            trigger OnValidate()
            begin
                IF "Starting Date" <> 0D THEN
                    IF "Ending Date" <> 0D THEN
                        IF "Starting Date" > "Ending Date" THEN
                            ERROR(gText003);
            end;
        }
        field(60; "Ending Date"; Date)
        {
            Caption = 'Ending Date';

            trigger OnValidate()
            begin
                IF "Ending Date" <> 0D THEN
                    IF "Starting Date" <> 0D THEN
                        IF "Starting Date" > "Ending Date" THEN
                            ERROR(gText003);
            end;
        }
        field(70; "Print Setup ID"; Code[10])
        {
            Caption = 'Print Setup ID';
            TableRelation = "LSC POS Print Setup Header"."Setup ID";
            ValidateTableRelation = true;
        }
        field(80; "Print Require ID"; Code[10])
        {
            Caption = 'Print Require ID';
            TableRelation = "LSC POS Print Setup Header"."Setup ID";
            ValidateTableRelation = true;
        }
        field(90; "Official Page Url"; Text[250])
        {
            Caption = 'Official Page Url';
        }
        field(100; "Use Inventory"; Boolean)
        {
            Caption = 'Use Inventory';
        }
        field(110; "Item Journal Template"; Code[10])
        {
            Caption = 'Item Journal Template';
            TableRelation = "Item Journal Template".Name WHERE(Type = CONST(Transfer));
            //This property is currently not supported
            //TestTableRelation = true;
            ValidateTableRelation = true;
        }
        field(120; "Transfer-to Code"; Code[10])
        {
            Caption = 'Transfer-to Code';
            TableRelation = Location.Code;
            ValidateTableRelation = false;
        }
        field(130; Coupon; Boolean)
        {
            Caption = 'Coupon';
        }
        field(140; "Control Type"; Option)
        {
            Caption = 'Control Type';
            OptionCaption = 'None,Delivery To Vendor';
            OptionMembers = "None",DeliveryToVendor;
        }
        field(150; "Authorization Type"; Option)
        {
            Caption = 'Authorization Type';
            OptionCaption = 'None,Web Page';
            OptionMembers = "None",WebPage;
        }
        field(160; "Type Recovery"; Option)
        {
            Caption = 'Type Recovery';
            OptionCaption = 'CreditNote,Product';
            OptionMembers = CreditNote,Product;
        }
        field(170; "Cust. Disc. Group Filter"; Code[20])
        {
            Caption = 'Cust. Disc. Group Filter';
            TableRelation = "Customer Discount Group".Code;
        }
    }

    keys
    {
        key(Key1; "No.")
        {
            Clustered = true;
        }
    }

    fieldgroups
    {
    }

    trigger OnDelete()
    begin
        POSExchLink.RESET;
        POSExchLink.SETFILTER(POSExchLink."POS Exchange No.", "No.");
        IF POSExchLink.FINDFIRST THEN
            ERROR(STRSUBSTNO(gText001, "No."));

        CreateAction(2);
    end;

    trigger OnInsert()
    begin
        "Use Inventory" := TRUE;
        CreateAction(0);
    end;

    trigger OnModify()
    begin
        VALIDATE("Starting Date");
        VALIDATE("Ending Date");

        IF FORMAT(xRec) <> FORMAT(Rec) THEN
            CreateAction(1);
    end;

    trigger OnRename()
    begin
        POSExchLink.RESET;
        POSExchLink.SETFILTER(POSExchLink."POS Exchange No.", "No.");
        IF POSExchLink.FINDFIRST THEN
            ERROR(STRSUBSTNO(gText001, "No."));

        IF FORMAT(xRec) <> FORMAT(Rec) THEN
            CreateAction(3);
    end;

    var
        POSExchLink: Record "FSN POS Exchange Item Link";
        gText001: Label 'Cant be delete because Exchange Links exists. Value %1';
        gText002: Label 'Cant be modify because Exchange Links exists. Value %1';
        gText003: Label 'Starting Date and Ending Date is not coherent';

    procedure ValidateRecord()
    begin
    end;

    procedure CreateAction(Type: Integer)
    var
        RecRef: RecordRef;
        xRecRef: RecordRef;
        ActionsMgt: Codeunit "LSC Actions Management";
    begin
        //LS
        //CreateAction
        //Type: 0 = INSERT, 1 = MODIFY, 2 = DELETE, 3 = RENAME
        //
        RecRef.GETTABLE(Rec);
        xRecRef.GETTABLE(xRec);
        ActionsMgt.SetCalledByTableTrigger(TRUE);

        ActionsMgt.CreateActionsByRecRef(RecRef, xRecRef, Type);
        RecRef.CLOSE;
        xRecRef.CLOSE;
    end;
}


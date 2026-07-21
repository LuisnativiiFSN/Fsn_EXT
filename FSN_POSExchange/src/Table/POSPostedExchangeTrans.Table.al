table 50091 "POS Posted Exchange Trans."
{

    Caption = 'FSN POS Posted Exchange Trans.';

    fields
    {
        field(10; "Receipt No."; Code[20])
        {
            Caption = 'Receipt No.';
        }
        field(11; "Transaction No."; Integer)
        {
            Caption = 'Transaction No.';
        }
        field(20; "Line No."; Integer)
        {
            Caption = 'Line No.';
        }
        field(29; "Barcode No."; Code[20])
        {

            trigger OnValidate()
            var
                Barcode_l: Record "LSC Barcodes";
                lText001: Label 'Barcode %1 not exists';
                lText002: Label 'Item %1 of barcode %2 not exists';
                ExchLinks_l: Record "FSN POS Exchange Item Link";
                Item_l: Record "Item";
                lText003: Label 'Exchange Setup for item %1 not found. ';
                ExchSetup_l: Record "FSN POS Exchange Setup";
                Done_: Boolean;
            begin
                Done_ := FALSE;
                IF Barcode_l.GET("Barcode No.") THEN BEGIN
                    IF Item_l.GET(Barcode_l."Item No.") THEN BEGIN
                        ExchLinks_l.RESET;
                        ExchLinks_l.SETRANGE(ExchLinks_l."Item No.", Item_l."No.");
                        IF ExchLinks_l.FIND('-') THEN BEGIN
                            REPEAT
                                IF NOT ExchSetup_l.GET(ExchLinks_l."POS Exchange No.") THEN
                                    ERROR(STRSUBSTNO(gText005, ExchLinks_l."POS Exchange No.", ExchSetup_l.TABLECAPTION));
                                IF ((ExchSetup_l."Starting Date" = 0D) OR (ExchSetup_l."Starting Date" <= TODAY)) AND
                                  ((ExchSetup_l."Ending Date" = 0D) OR (ExchSetup_l."Ending Date" >= TODAY)) THEN BEGIN
                                    "Item No." := ExchLinks_l."Item No.";
                                    "Unit of Measure" := ExchLinks_l."Unit of Measure";
                                    "POS Exchange No." := ExchLinks_l."POS Exchange No.";
                                    "Use Inventory" := ExchLinks_l."Use Inventory";
                                    Quantity := ExchSetup_l."Quantity Gift";
                                    Done_ := TRUE;
                                END;
                            UNTIL (ExchLinks_l.NEXT = 0) OR Done_;
                            IF NOT Done_ THEN
                                MESSAGE(STRSUBSTNO(lText003, GetItemDescription(Item_l."No.")));
                        END ELSE BEGIN
                            MESSAGE(STRSUBSTNO(lText003, GetItemDescription(Item_l."No.")));
                        END;

                    END ELSE
                        ERROR(STRSUBSTNO(lText002, Item_l."No.", "Barcode No."));
                END ELSE
                    ERROR(STRSUBSTNO(lText001, "Barcode No."));
            end;
        }
        field(30; "Item No."; Code[20])
        {
            Editable = false;
            Enabled = true;

            trigger OnValidate()
            var
                Item_l: Record "Item";
            begin
                IF NOT Item_l.GET("Item No.") THEN
                    ERROR(STRSUBSTNO(gText005, "Item No.", Item_l.TABLECAPTION));
                "Unit of Measure" := '';
            end;
        }
        field(40; "Unit of Measure"; Code[10])
        {
            Caption = 'Unit of Measure';
            TableRelation = "Item Unit of Measure".Code WHERE("Item No." = FIELD("Item No."));
        }
        field(50; Quantity; Integer)
        {
            Caption = 'Quantity';
        }
        field(60; "Store No."; Code[10])
        {
            Caption = 'Store No.';
            TableRelation = "LSC Store"."No.";

            trigger OnValidate()
            begin
                "POS Terminal No." := '';
            end;
        }
        field(70; "POS Terminal No."; Code[10])
        {
            Caption = 'POS Terminal No.';
            TableRelation = "LSC POS Terminal"."No." WHERE("Store No." = FIELD("Store No."));
        }
        field(80; Status; Option)
        {
            Caption = 'Status';
            OptionCaption = 'Open,Released,Send,Created Request,Confirmed Request,Exit Applied,Liquidated Product,Liquidated CreditNote,Void';
            OptionMembers = Open,Released,Send,"Created Request","Confirmed Request","Exit Applied","Liquidated Product","Liquidated CreditNote",Void;
        }
        field(90; "Transfer Order No."; Code[20])
        {
            Caption = 'Transfer Order No.';
        }
        field(100; "Staff ID"; Code[20])
        {
            Caption = 'Staff ID';
            TableRelation = "LSC Staff".ID;
        }
        field(110; "Sales Staff"; Code[20])
        {
            Caption = 'Sales Staff';
            TableRelation = "LSC Staff".ID;
        }
        field(120; "Customer No."; Code[20])
        {
            Caption = 'Customer No.';
            Editable = false;
            Enabled = true;
            //This property is currently not supported
            //TestTableRelation = true;
            //The property 'ValidateTableRelation' can only be set if the property 'TableRelation' is set
            //ValidateTableRelation = true;

            trigger OnValidate()
            var
                Customer_l: Record "Customer";
            begin
                IF NOT Customer_l.GET("Customer No.") THEN
                    ERROR(STRSUBSTNO(gText005, "Customer No.", Customer_l.TABLECAPTION));
            end;
        }
        field(130; "Customer Sub Code"; Code[20])
        {
            Caption = 'Customer Sub Code';
        }
        field(140; "Transaction Date"; Date)
        {
            Caption = 'Transaction Date';
        }
        field(141; "Origin Line Detected"; Integer)
        {
            Caption = 'Origin Line Detected';
        }
        field(150; "POS Exchange No."; Code[20])
        {
            Caption = 'POS Exchange No.';
            TableRelation = "FSN POS Exchange Item Link"."POS Exchange No." WHERE("Item No." = FIELD("Item No."),
                                                                               "Unit of Measure" = FIELD("Unit of Measure"));
            ValidateTableRelation = true;

            trigger OnValidate()
            var
                ExchSetup_l: Record "FSN POS Exchange Setup";
            begin
                ExchSetup_l.GET("POS Exchange No.");
                IF NOT ((ExchSetup_l."Starting Date" = 0D) OR (ExchSetup_l."Starting Date" <= TODAY)) AND
                  ((ExchSetup_l."Ending Date" = 0D) OR (ExchSetup_l."Ending Date" >= TODAY)) THEN
                    ERROR(STRSUBSTNO(gText006, ExchSetup_l."No.", FORMAT(ExchSetup_l."Starting Date"), FORMAT(ExchSetup_l."Ending Date")));


                Quantity := ExchSetup_l."Quantity Gift";
                "Use Inventory" := ExchSetup_l."Use Inventory";
            end;
        }
        field(160; "Posting Date"; Date)
        {
            Caption = 'Posting Date';
        }
        field(170; "Use Inventory"; Boolean)
        {
            Caption = 'Use Inventory';
        }
        field(180; Complete; Boolean)
        {
            Caption = 'Complete';
        }
        field(190; "Process Message"; Text[100])
        {
            Caption = 'Process Message';
        }
        field(200; "External Document No."; Code[20])
        {
            Caption = 'Credit Note/External Document No.';
        }
        field(201; "Amount Doc. Inc. VAT"; Decimal)
        {
            Caption = 'Amount Doc. Inc. VAT';
        }
        field(210; "Transfer-to Code"; Code[30])
        {
            Caption = 'Transfer-to Code';
        }
        field(211; "User NAV"; Code[50])
        {
        }
        field(220; "Unit Cost"; Decimal)
        {
            Caption = 'Unit Cost';
        }
        field(230; "Attrib 1 Code"; Text[30])
        {
            CalcFormula = Lookup(Item."LSC Attrib 1 Code" WHERE("No." = FIELD("Item No.")));
            Caption = 'Attrib 1 Code';
            FieldClass = FlowField;
        }
        field(240; "Vendor Document No."; Code[20])
        {
            Caption = 'Vendor Document No.';
        }
        field(250; Request; Option)
        {
            Caption = 'Request';
            OptionCaption = 'None,Delivery to Vendor,Delivered,Received by Vendor';
            OptionMembers = "None",DeliveryToVendor,Delivered,ReceivedByVendor;
        }
        field(270; "Document Return Key 1"; Code[50])
        {
            Caption = 'Document Return Key 1';
        }
        field(271; "Document Return Key 2"; Integer)
        {
        }
        field(280; "Web Authorization No."; Text[20])
        {
            Caption = 'Web Authorization No.';
        }
        field(290; "Document Receipt Key 1"; Code[50])
        {
        }
        field(291; "Document Receipt Key 2"; Integer)
        {
        }
        field(300; "Autorization Type"; Option)
        {
            Caption = 'Autorization Type';
            OptionCaption = 'None,Web';
            OptionMembers = "None",Web;
        }
    }

    keys
    {
        key(Key1; "Receipt No.", "Transaction No.", "Line No.", "Store No.", "POS Terminal No.")
        {
            Clustered = true;
        }
        key(Key2; Status, "Transfer Order No.")
        {
        }
        key(Key3; "Receipt No.", "Transfer Order No.", "Store No.", Status, "Use Inventory", Complete)
        {
        }
        key(Key4; Request, "Document Return Key 1", "Document Return Key 2")
        {
        }
        key(Key5; "Document Receipt Key 1", "Document Receipt Key 2", "Autorization Type")
        {
        }
    }

    fieldgroups
    {
    }

    trigger OnDelete()
    begin
        TESTFIELD(Status, Status::Open);
    end;

    trigger OnInsert()
    begin
        ValidateRecord(FALSE);
    end;

    trigger OnModify()
    var
        lText001: Label 'Cant be modify';
    begin
        ERROR(lText001);
        IF xRec.Status <> xRec.Status::Open THEN
            ERROR(STRSUBSTNO(gText004, xRec.Status));
        ValidateRecord(TRUE);
    end;

    trigger OnRename()
    begin
        IF xRec.Status <> xRec.Status::Open THEN
            ERROR(STRSUBSTNO(gText004, xRec.Status));
    end;

    var
        gText001: Label 'Field %1 cant be emtpy.';
        gText002: Label 'Fields %1, %2 or %3 cant be empty.';
        POSExchSetup: Record "FSN POS Exchange Setup";
        POSExchLinks: Record "FSN POS Exchange Item Link";
        gText003: Label 'Setup no exists. Value %1 %2 %3';
        gText004: Label 'Cant be modify in status %1';
        gText005: Label 'Value %1 not exists in Table %2';
        gText006: Label 'Date of POS Exchange %1 is not valid. From %2 To %3 ...';

    procedure GetItemDescription(No_: Code[20]) ReturnDescr: Text[50]
    var
        Item_l: Record "Item";
    begin
        IF Item_l.GET(No_) THEN
            EXIT(Item_l.Description);

        EXIT('');
    end;

    procedure ValidateRecord(Modify: Boolean)
    var
        LineOrigin_l: Integer;
        ExchangeTrans_l: Record "FSN POS Exchange Transaction";
        POSTransLine_l: Record "LSC POS Trans. Line";
    begin
        LineOrigin_l := 0;
        IF "POS Exchange No." = '' THEN
            "Use Inventory" := TRUE;

        IF NOT (("Receipt No." <> '') OR ("Store No." <> '') OR ("POS Terminal No." <> '')) THEN
            ERROR(STRSUBSTNO(gText002, "Receipt No.", "Store No.", "POS Terminal No."));

        IF Modify THEN BEGIN
            IF "POS Exchange No." = '' THEN
                MESSAGE(STRSUBSTNO(gText001, FIELDCAPTION("POS Exchange No.")));

            IF "POS Exchange No." <> '' THEN BEGIN
                IF NOT POSExchLinks.GET("POS Exchange No.", "Item No.", "Unit of Measure") THEN
                    MESSAGE(STRSUBSTNO(gText003, "POS Exchange No.", "Item No.", "Unit of Measure"));

                IF NOT POSExchSetup.GET(POSExchLinks."POS Exchange No.") THEN
                    ERROR(STRSUBSTNO(gText003, "POS Exchange No."));
            END;
        END;

        IF NOT Modify THEN BEGIN
            ExchangeTrans_l.RESET;
            ExchangeTrans_l.SETCURRENTKEY("Receipt No.", "Transaction No.", "Line No.", "Store No.", "POS Terminal No.");
            ExchangeTrans_l.SETRANGE(ExchangeTrans_l."Receipt No.", "Receipt No.");
            IF ExchangeTrans_l.FINDLAST THEN
                "Line No." := ExchangeTrans_l."Line No." + 10000
            ELSE
                "Line No." := 10000;
        END;

        IF "Item No." <> '' THEN BEGIN
            POSTransLine_l.RESET;
            POSTransLine_l.SETRANGE(POSTransLine_l."Receipt No.", "Receipt No.");
            POSTransLine_l.SETRANGE(POSTransLine_l.Number, "Item No.");
            IF POSTransLine_l.FINDSET THEN
                REPEAT
                    IF (POSTransLine_l.Number = "Item No.") AND (POSTransLine_l."Unit of Measure" = "Unit of Measure") THEN
                        LineOrigin_l := POSTransLine_l."Line No.";
                UNTIL (POSTransLine_l.NEXT = 0) OR (LineOrigin_l <> 0);
            "Origin Line Detected" := LineOrigin_l;
        END;

        IF NOT Modify THEN
            Status := Status::Open;
    end;

    procedure PreValidationsStores(StoreDestiny: Code[10]; StoreOrigin: Code[10]; var ProcessError: Text[100]) Ok_: Boolean
    var
        Store_l: Record "LSC Store";
        Location_l: Record "Location";
        lText001: Label 'Location %2 %1 not exists.';
        lText002: Label 'Store %2 %1 not exists.';
        lText003: Label 'Location %2 %1 is not active for Transfering';
        lText004: Label 'Origin';
        lText005: Label 'Destiny';
    begin
        ProcessError := '';
        IF NOT Store_l.GET(StoreDestiny) THEN
            ProcessError := COPYSTR(STRSUBSTNO(lText002, lText005, StoreDestiny), 1, 100)
        ELSE
            IF NOT Location_l.GET(Store_l."Location Code") THEN
                ProcessError := COPYSTR(STRSUBSTNO(lText001, lText005, Store_l."Location Code"), 1, 100)
            ELSE
                /*IF NOT Location_l."Use Transfer" THEN
                  ProcessError := COPYSTR(STRSUBSTNO(lText003,lText005,Location_l.Name),1,100);*/ //Revisar Campo

                IF ProcessError <> '' THEN
                    EXIT(FALSE);

        IF NOT Store_l.GET(StoreOrigin) THEN
            ProcessError := COPYSTR(STRSUBSTNO(lText002, lText004, StoreOrigin), 1, 100)
        ELSE
            IF NOT Location_l.GET(Store_l."Location Code") THEN
                ProcessError := COPYSTR(STRSUBSTNO(lText001, lText004, Store_l."Location Code"), 1, 100)
            ELSE
                /*IF NOT Location_l."Use Transfer" THEN
                  ProcessError := COPYSTR(STRSUBSTNO(lText003,lText004,Location_l.Name),1,100);*/ //Revisar Campo

                IF ProcessError <> '' THEN
                    EXIT(FALSE);
        EXIT(TRUE);
    end;
}


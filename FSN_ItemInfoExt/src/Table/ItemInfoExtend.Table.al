table 50010 "FSN Item Info. Extend"
{
    //WVILLALTA 10.21             - C/AL to AL

    Caption = 'Item Info. Extend';

    fields
    {
        field(10; "Entry Type"; Option)
        {
            Caption = 'Entry Type';
            OptionCaption = 'Item Information,Type Item Information,Ecommerce-Limit-Inventory,Ecommerce-Hierarchy,Ecommerce-Item,Ecommerce-Prices,Parameters';
            OptionMembers = ItemInformation,TypeItemInformation,EcommerceLimit,EcommerceHierarchy,EcommerceItem,EcommercePrices,Parameters;
        }
        field(20; "Sub Type"; Option)
        {
            Caption = 'Sub Type';
            OptionCaption = 'Information,ItemSetting,ItemImage,ItemLink';
            OptionMembers = Information,ItemSetting,ItemImage,ItemLink;
        }
        field(30; "No."; Code[30])
        {//116912270

            TableRelation = IF ("Entry Type" = CONST(ItemInformation)) Item."No."
            ELSE
            IF ("Entry Type" = FILTER(EcommerceLimit | EcommerceItem),
                                     "Sub Type" = CONST(ItemSetting),
                                     "Item Type" = CONST(Item)) Item."No."
            ELSE
            IF ("Entry Type" = FILTER(EcommerceLimit | EcommerceItem),
                                              "Sub Type" = CONST(ItemSetting),
                                              "Item Type" = CONST(ProductGroup)) "LSC Retail Product Group".Code //"Product Group".Code
            ELSE
            IF ("Entry Type" = FILTER(EcommerceLimit | EcommerceItem),
                                                       "Sub Type" = CONST(ItemSetting),
                                                       "Item Type" = CONST(Category)) "Item Category".Code
            ELSE
            IF ("Entry Type" = FILTER(EcommerceLimit | EcommerceItem),
                                                                "Sub Type" = CONST(ItemSetting),
                                                                "Item Type" = CONST(Division)) "LSC Division".Code
            ELSE
            IF ("Entry Type" = FILTER(EcommerceLimit | EcommerceItem),
                                                                         "Sub Type" = CONST(ItemSetting),
                                                                         "Item Type" = CONST("Attribute 1")) "LSC Attribute Option Value"."Option Value"; /*WHERE("Attribute Type" = CONST(Item),
                                                                                                                                                       "Attribute Code" = CONST(LABORATORIO));*///REVISAR


            trigger OnValidate()
            begin
                IF ("Entry Type" IN [0]) OR (("Item Type" = 0) AND ("Entry Type" IN [2, 4, 5])) THEN
                    IF Item.GET("No.") AND
                      ("Unit of Measure" <> Item."Base Unit of Measure") OR ("Unit of Measure" <> Item."Purch. Unit of Measure") THEN
                        "Unit of Measure" := Item."Base Unit of Measure";
            end;

        }
        field(40; ID; Code[20])
        {
            TableRelation = IF ("Entry Type" = CONST(ItemInformation)) "FSN Item Info. Extend"."No." WHERE("Entry Type" = CONST(TypeItemInformation));

        }
        field(50; "Unit of Measure"; Code[20])
        {
            Caption = 'Unit of Measure';
            TableRelation = IF ("Item Type" = CONST(Item),
                                "Sub Type" = FILTER(<> ItemLink)) "Item Unit of Measure".Code WHERE("Item No." = FIELD("No."))
            ELSE
            IF ("Sub Type" = CONST(ItemLink)) Item."No.";
            ValidateTableRelation = false;
        }
        field(60; "Line No."; Integer)
        {
            Caption = 'Line No.';
        }
        field(70; Quantity; Decimal)
        {
            Caption = 'Quantity';
            MinValue = 0;
        }
        field(80; Description; Text[50])
        {
            Caption = 'Description';
        }
        field(90; "Free Text"; Text[250])
        {
            Caption = 'Free Text';
        }
        field(100; Sort; Integer)
        {
            Caption = 'Sort';
        }
        field(110; "Blocked Ecommerce"; Boolean)
        {
            Caption = 'Blocked Ecommerce';
            Description = 'Version 2.0';
        }
        field(120; Reason; Text[50])
        {
            Caption = 'Reason';
            Description = 'Version 2.0';
        }
        field(130; "Starting Date"; Date)
        {
            Caption = 'Starting Date';
            Description = 'Version 2.0';

            trigger OnValidate()
            begin
                IF "Starting Date" = 0D THEN
                    "Start Time" := 0T;
            end;
        }
        field(135; "Start Time"; Time)
        {
            Caption = 'Start Time';
            Description = 'Version 2.0';

            trigger OnValidate()
            begin
                VALIDATE("Starting Date");
            end;
        }
        field(140; "Ending Date"; Date)
        {
            Caption = 'Ending Date';
            Description = 'Version 2.0';

            trigger OnValidate()
            begin
                IF "Ending Date" = 0D THEN
                    "End Time" := 0T;
            end;
        }
        field(145; "End Time"; Time)
        {
            Caption = 'End Time';
            Description = 'Version 2.0';

            trigger OnValidate()
            begin
                VALIDATE("Ending Date");
            end;
        }
        field(150; "Source Type"; Option)
        {
            Caption = 'Source Type';
            Description = 'Version 2.0';
            OptionCaption = 'Inicialize,Automatic,Copy Temporary,AutomaticStatic';
            OptionMembers = Inicialize,Automatic,CopyTemporary,AutomaticStatic;
        }
        field(160; "Item Type"; Option)
        {
            Caption = 'Item Type';
            Description = 'Version 2.0';
            OptionCaption = 'Item,ProductGroup,Category,Division,Attribute 1,SpecialGroup,All,Attribute 2,Attribute 3';
            OptionMembers = Item,ProductGroup,Category,Division,"Attribute 1",SpecialGroup,All,"Attribute 2","Attribute 3";
        }
        field(170; "Last Date Modify"; DateTime)
        {
            Caption = 'Last Date Modify';
            Description = 'Version 2.0';
        }
        field(180; "Last User Modify"; Code[50])
        {
            Caption = 'Last User Modify';
            Description = 'Version 2.0';

            trigger OnValidate()
            begin
                "Last Date Modify" := CURRENTDATETIME;
            end;
        }
        field(500; "Hierarchy Parent Code"; Code[30])
        {
            Caption = 'Hierarchy Parent Code';
            Description = 'Version 2.0';
        }
        field(510; "Minimum Quantity Sale"; Decimal)
        {
            Caption = 'Minimum Quantity Sale';
            Description = 'Version 2.0';
            MinValue = 0;
        }
        field(520; "Maximum Quantity Sale"; Decimal)
        {
            Caption = 'Maximum Quantity Sale';
            Description = 'Version 2.0';
            MinValue = 0;
        }
        field(530; "Require Medical Document"; Boolean)
        {
            Caption = 'Require Medical Document';
            Description = 'Version 2.0';
        }
        field(540; "Price Default"; Decimal)
        {
            Caption = 'Price Default';
            Description = 'Version 2.0';
            MinValue = 0;
        }
        field(550; "Price Inc. Disc. Default"; Decimal)
        {
            Caption = 'Price Inc. Disc. Default';
            Description = 'Version 2.0';
            MinValue = 0;
        }
        field(560; "Discount Default"; Decimal)
        {
            Caption = 'Discount Default';
            Description = 'Version 2.0';
            MinValue = 0;
        }
        field(570; "Tag Discount Default"; Text[20])
        {
            Caption = 'Tag Discount Default';
            Description = 'Version 2.0';
        }
        field(580; "Mark Code"; Text[50])
        {
            Caption = 'Mark Code';
            Description = 'Version 2.0';
        }
        field(590; "Image Link"; Text[250])
        {
            Caption = 'Image Link';
        }
    }

    keys
    {
        key(Key1; "Entry Type", "Sub Type", "No.", "Unit of Measure", "Line No.")
        {
            Clustered = true;
        }
        key(Key2; Sort)
        {
        }
        key(Key3; "Entry Type", "Sub Type", "Starting Date", "Start Time")
        {
        }
    }

    fieldgroups
    {
    }

    trigger OnDelete()
    begin
        IF "Entry Type" > 2 THEN
            IF "Source Type" = "Source Type"::AutomaticStatic THEN
                ERROR(STRSUBSTNO(Text002, FIELDCAPTION("Source Type"), FORMAT("Source Type"::AutomaticStatic)));
        CheckOnDelete(Rec);
        CreateAction(2);
    end;

    trigger OnInsert()
    begin
        TESTFIELD("No.");

        IF ("Entry Type" = "Entry Type"::ItemInformation) AND ("Line No." = 0) THEN BEGIN
            ItemInfoExt.RESET;
            ItemInfoExt.SETCURRENTKEY("Entry Type", "Sub Type", "No.", "Unit of Measure", "Line No.");
            ItemInfoExt.SETRANGE(ItemInfoExt."Entry Type", "Entry Type");
            ItemInfoExt.SETRANGE(ItemInfoExt."Sub Type", "Sub Type");
            ItemInfoExt.SETRANGE(ItemInfoExt."No.", "No.");
            ItemInfoExt.SETRANGE(ItemInfoExt."Unit of Measure", "Unit of Measure");
            IF ItemInfoExt.FIND('+') THEN
                "Line No." := ItemInfoExt."Line No." + 1000
            ELSE
                "Line No." += 1000;
        END;
        IF "Entry Type" IN ["Entry Type"::EcommerceLimit,
                                        "Entry Type"::EcommerceHierarchy,
                                        "Entry Type"::EcommerceItem,
                                        "Entry Type"::EcommercePrices] THEN BEGIN

            IF ("Item Type" = 0) AND ("Entry Type" IN ["Entry Type"::EcommerceLimit, "Entry Type"::EcommerceItem]) THEN
                IF NOT ("Source Type" = "Source Type"::CopyTemporary) THEN
                    CheckOnInsertEcommItem(Rec);

        END;
        VALIDATE("Last User Modify", USERID);

        CheckInfo;
        CreateAction(0);
    end;

    trigger OnModify()
    begin
        VALIDATE("Last User Modify", USERID);

        CheckInfo;
        CreateAction(1);
    end;

    trigger OnRename()
    begin
        ERROR(Text001);
    end;

    procedure CheckInfo()
    var
        PeriodicDiscount_l: Record "LSC Periodic Discount";
        AttributeSetup_l: Record "LSC Attribute Setup";
        Txt1: Label 'Offer: %1';
    begin
        AttributeSetup_l.Get();
        IF "Entry Type" = Rec."Entry Type"::ItemInformation THEN
            IF Item.GET("No.") THEN
                Rec.Description := Item.Description;

        IF ("Entry Type" IN ["Entry Type"::EcommerceLimit,
                                "Entry Type"::EcommerceHierarchy,
                                "Entry Type"::EcommerceItem,
                                "Entry Type"::EcommercePrices]) AND ("Source Type" <> "Source Type"::CopyTemporary)
            THEN
            CASE "Item Type" OF
                "Item Type"::Item:
                    BEGIN
                        ItemBarcodes.RESET;
                        ItemBarcodes.SETCURRENTKEY("Item No.", "Variant Code", "Unit of Measure Code");
                        ItemBarcodes.SETRANGE(ItemBarcodes."Item No.", "No.");
                        IF "Unit of Measure" <> '' THEN
                            ItemBarcodes.SETRANGE(ItemBarcodes."Unit of Measure Code", "Unit of Measure");
                        IF ItemBarcodes.FIND('-') THEN
                            Description := CopyStr(ItemBarcodes.Description, 1, 50);

                        IF Item.GET("No.") THEN BEGIN
                            IF Description = '' THEN
                                Description := CopyStr(Item.Description, 1, 50);
                            "Mark Code" := GetItemAttrib1CodeClear(Item."LSC Attrib 1 Code");
                        END;
                    END;
                "Item Type"::ProductGroup:
                    BEGIN
                        IF "Sub Type" = "Sub Type"::ItemLink THEN BEGIN
                            IF Item.GET("Unit of Measure") THEN BEGIN
                                Description := Item.Description;
                                "Mark Code" := GetItemAttrib1CodeClear(Item."LSC Attrib 1 Code");
                            END ELSE
                                IF PeriodicDiscount_l.GET("Unit of Measure") THEN BEGIN
                                    Description := STRSUBSTNO(Txt1, PeriodicDiscount_l.Description);
                                    Sort := 100; //Sub type Offer
                                END;
                        END ELSE BEGIN
                            ProductGroup.RESET;
                            ProductGroup.SETFILTER("Code", "No.");
                            IF ProductGroup.FIND('-') THEN
                                Description := ProductGroup.Description;
                        END;
                    END;
                "Item Type"::Category:
                    BEGIN
                        IF "Sub Type" = "Sub Type"::ItemLink THEN BEGIN
                            IF Item.GET("Unit of Measure") THEN BEGIN
                                Description := Item.Description;
                                "Mark Code" := GetItemAttrib1CodeClear(Item."LSC Attrib 1 Code");
                            END ELSE
                                IF PeriodicDiscount_l.GET("Unit of Measure") THEN BEGIN
                                    Description := STRSUBSTNO(Txt1, PeriodicDiscount_l.Description);
                                    Sort := 100; //Sub type Offer
                                END;
                        END ELSE
                            IF ItemCategory.GET("No.") THEN
                                Description := ItemCategory.Description;
                    END;
                "Item Type"::Division:
                    BEGIN
                        IF "Sub Type" = "Sub Type"::ItemLink THEN BEGIN
                            IF Item.GET("Unit of Measure") THEN BEGIN
                                Description := Item.Description;
                                "Mark Code" := GetItemAttrib1CodeClear(Item."LSC Attrib 1 Code");
                            END ELSE
                                IF PeriodicDiscount_l.GET("Unit of Measure") THEN BEGIN
                                    Description := STRSUBSTNO(Txt1, PeriodicDiscount_l.Description);
                                    Sort := 100; //Sub type Offer
                                END;
                        END ELSE
                            IF ItemDivision.GET("No.") THEN
                                Description := ItemDivision.Description;
                    END;
                "Item Type"::"Attribute 1",
                "Item Type"::"Attribute 2",
                "Item Type"::"Attribute 3":
                    BEGIN
                        AttributeOptionVal.RESET;
                        //AttributeOptionVal.SETRANGE(AttributeOptionVal."Attribute Type", AttributeOptionVal."Attribute Type"::Item);
                        IF "Item Type" = "Item Type"::"Attribute 1" THEN
                            AttributeOptionVal.SETRANGE(AttributeOptionVal."Attribute Code", AttributeSetup_l."Item Attrib. 1 Code")
                        ELSE
                            IF "Item Type" = "Item Type"::"Attribute 2" THEN
                                AttributeOptionVal.SETRANGE(AttributeOptionVal."Attribute Code", AttributeSetup_l."Item Attrib. 2 Code")
                            ELSE
                                AttributeOptionVal.SETRANGE(AttributeOptionVal."Attribute Code", AttributeSetup_l."Item Attrib. 3 Code");
                        AttributeOptionVal.SETRANGE(AttributeOptionVal."Option Value", "No.");
                        IF AttributeOptionVal.FIND('-') THEN
                            Description := AttributeOptionVal."Option Value";
                    END;
                "Item Type"::SpecialGroup:
                    BEGIN
                        IF SpecialGroup.GET("No.") THEN
                            Description := SpecialGroup.Description;
                    END;
            END;


        IF Rec."Entry Type" IN [Rec."Entry Type"::ItemInformation, Rec."Entry Type"::TypeItemInformation] THEN
            Rec.TESTFIELD("Sub Type", Rec."Sub Type"::Information);

        IF Rec."Entry Type" IN [Rec."Entry Type"::EcommerceLimit, Rec."Entry Type"::EcommerceHierarchy, Rec."Entry Type"::EcommerceItem] THEN BEGIN
            IF Rec."Unit of Measure" = '' THEN
                IF Rec."Item Type" = Rec."Item Type"::Item THEN
                    IF Item.GET(COPYSTR(Rec."No.", 1, 20)) THEN
                        Rec.VALIDATE("Unit of Measure", Item."Base Unit of Measure");
        END;
    end;

    procedure CheckOnInsertEcommItem(var Rec: Record "FSN Item Info. Extend")
    begin
        IF Rec."Entry Type" = Rec."Entry Type"::EcommerceItem THEN BEGIN
            Rec."Blocked Ecommerce" := TRUE;
            Rec.Reason := Txt2;
            Rec."Source Type" := Rec."Source Type"::Inicialize;
            Rec."Item Type" := 0;
            Rec."Minimum Quantity Sale" := 1;
            Rec."Maximum Quantity Sale" := 9999;//Max limit
        END;
    end;

    procedure CheckOnDelete(Rec: Record "FSN Item Info. Extend")
    begin
        IF Rec."Entry Type" <> Rec."Entry Type"::EcommerceLimit THEN
            IF Rec."Source Type" = Rec."Source Type"::AutomaticStatic THEN
                ERROR(STRSUBSTNO(Txt7, Rec.FIELDCAPTION("Source Type"), FORMAT(Rec."Source Type"::AutomaticStatic)));
        IF Rec."Entry Type" = Rec."Entry Type"::EcommerceItem THEN BEGIN
            ItemInfoExt.RESET;
            ItemInfoExt.SETRANGE(ItemInfoExt."Entry Type", ItemInfoExt."Entry Type"::EcommercePrices);
            ItemInfoExt.SETRANGE(ItemInfoExt."Sub Type", ItemInfoExt."Sub Type"::ItemSetting);
            ItemInfoExt.SETRANGE(ItemInfoExt."Unit of Measure", Rec."Unit of Measure");
            ItemInfoExt.SETRANGE(ItemInfoExt."No.", Rec."No.");
            ItemInfoExt.DELETEALL(TRUE);
        END;
    end;

    procedure GetItemAttrib1CodeClear(pAttribute: Code[50]) ReturnTxt: Code[50]
    var
        NewAttrib: Code[50];
        NewPos: Integer;
        CounterPos: Integer;
        NewIsNumber: Integer;
        TxtIsNumber: Text[1];
        StringType: DotNet String;
        i: Integer;
    begin
        ReturnTxt := pAttribute;
        IF pAttribute = '' THEN
            EXIT;

        NewAttrib := DELCHR(pAttribute, '=', '-');
        CounterPos := STRLEN(pAttribute) - STRLEN(NewAttrib);

        IF CounterPos = 0 THEN
            EXIT(pAttribute);

        IF CounterPos = 1 THEN BEGIN
            NewAttrib := COPYSTR(pAttribute, 1, STRPOS(pAttribute, '-') - 1);
            TxtIsNumber := COPYSTR(NewAttrib, STRLEN(NewAttrib), 1);
            IF EVALUATE(NewIsNumber, TxtIsNumber) THEN BEGIN

                ReturnTxt := COPYSTR(NewAttrib, 1, STRLEN(NewAttrib) - 1);
                IF STRLEN(ReturnTxt) > 0 THEN
                    IF EVALUATE(NewIsNumber, COPYSTR(ReturnTxt, STRLEN(ReturnTxt), 1)) THEN
                        ReturnTxt := COPYSTR(ReturnTxt, 1, STRLEN(ReturnTxt) - 1);
            END ELSE
                ReturnTxt := pAttribute;
        END ELSE BEGIN
            IF STRLEN(pAttribute) < 5 THEN
                EXIT;

            i := 1;
            NewPos := 0;
            NewAttrib := pAttribute;
            CounterPos := STRLEN(pAttribute);
            WHILE (CounterPos > i) AND (NewPos = 0) DO BEGIN
                TxtIsNumber := COPYSTR(pAttribute, CounterPos, 1);
                IF COPYSTR(pAttribute, CounterPos, 1) = '-' THEN BEGIN
                    IF CounterPos - 1 > 0 THEN
                        IF EVALUATE(NewIsNumber, COPYSTR(pAttribute, CounterPos - 1, 1)) THEN
                            NewPos := CounterPos - 2;
                    IF CounterPos - 2 > 0 THEN
                        IF EVALUATE(NewIsNumber, COPYSTR(pAttribute, CounterPos - 2, 1)) THEN
                            NewPos := CounterPos - 3;
                END;
                CounterPos -= 1;
            END;
            IF NewPos > 1 THEN
                ReturnTxt := COPYSTR(pAttribute, 1, NewPos);
        END;
        StringType := ReturnTxt;
        ReturnTxt := StringType.Trim;
    end;

    procedure CreateAction(Type: Integer)
    var
        RecRef: RecordRef;
        xRecRef: RecordRef;
        ActionsMgt: Codeunit "LSC Actions Management";
    begin
        //Type: 0 = INSERT, 1 = MODIFY, 2 = DELETE, 3 = RENAME

        RecRef.GETTABLE(Rec);
        xRecRef.GETTABLE(xRec);
        ActionsMgt.SetCalledByTableTrigger(TRUE);
        ActionsMgt.CreateActionsByRecRef(RecRef, xRecRef, Type);
        RecRef.CLOSE;
        xRecRef.CLOSE;
    end;

    var
        ItemBarcodes: Record "LSC Barcodes";
        ProductGroup: Record "LSC Retail Product Group";
        ItemCategory: Record "Item Category";
        ItemDivision: Record "LSC Division";
        AttributeOptionVal: Record "LSC Attribute Option Value";
        SpecialGroup: Record "LSC Item Special Groups";
        ItemInfoExt: Record "FSN Item Info. Extend";
        Item: Record Item;
        Text001: Label 'Cant be rename, delete record and insert new';
        Text002: Label 'Cant be delete. %1 %2';
        Txt2: Label 'Inicialize...';
        Txt7: Label 'Cant be delete %1 %2';
}


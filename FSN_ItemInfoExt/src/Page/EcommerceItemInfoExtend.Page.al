page 50019 "FSN Ecommerce Info Extend."
{
    // WVILLALTA 02.20                 - New Functions

    PageType = List;
    PromotedActionCategories = 'New,Admin,Process,,Actions,Inventory,Hierarchy,Adicionales';
    SourceTable = "FSN Item Info. Extend";
    SourceTableView = SORTING("Entry Type", "Sub Type", "No.", "Unit of Measure", "Line No.");
    Caption = 'Ecommerce Info. Extend';
    layout
    {
        area(content)
        {
            repeater(Group)
            {
                field("Entry Type";
                "Entry Type")
                {
                    Editable = false;
                    Style = Strong;
                    StyleExpr = TRUE;
                    Visible = EntryTypeVisible;
                }
                field("Sub Type";
                "Sub Type")
                {
                    Editable = SubTypeEditable;
                    Visible = SubTypeVisible;
                }
                field("Item Type";
                "Item Type")
                {
                    Editable = ItemTypeEditable;
                    Visible = ItemTypeVisible;
                }
                field("No."; "No.")
                {
                    Enabled = NoUMEditable;
                    TableRelation = IF ("Entry Type" = CONST(ItemInformation)) Item."No."
                    ELSE
                    IF ("Entry Type" = FILTER(EcommerceLimit | EcommerceItem),
                                             "Sub Type" = CONST(ItemSetting),
                                             "Item Type" = CONST(Item)) Item."No."
                    ELSE
                    IF ("Entry Type" = FILTER(EcommerceLimit | EcommerceItem),
                                                      "Sub Type" = CONST(ItemSetting),
                                                      "Item Type" = CONST(ProductGroup)) "LSC Retail Product Group".Code
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
                                                                                 "Item Type" = CONST("Attribute 1")) "LSC Attribute Option Value"."Option Value" WHERE //(Attribute Type=CONST(Item),
                                                                                                                                                               ("Attribute Code" = CONST('LABORATORIO'));
                    Visible = NoVisible;

                    trigger OnLookup(var Text: Text): Boolean
                    var
                        PAGEItem: Page "LSC Retail Item List";
                        PAGEDivision: Page "LSC Divisions";
                        PAGECategory: Page "Item Categories";
                        PAGEProductGroup: Page "LSC Retail Product Groups";
                        PAGEAttribLookUp: Page "LSC Attribute Options Lookup";
                        PAGESpecialGroup: Page "LSC Special Groups";
                        Actionl: Action;
                        Item_l: Record "Item";
                        Division_l: Record "LSC Division";
                        Category_l: Record "Item Category";
                        ProductGroup_l: Record "LSC Retail Product Group";
                        SpecialGroup_l: Record "LSC Item Special Groups";
                        Atrributes_l: Record "LSC Attribute Option Value";
                        AttributeSetup_l: Record "LSC Attribute Setup";
                    begin
                        AttributeSetup_l.Get();
                        CASE "Item Type" OF
                            "Item Type"::Item:
                                BEGIN
                                    Item_l.RESET;
                                    Actionl := PAGE.RUNMODAL(PAGE::"LSC Retail Item List", Item_l);
                                    IF Actionl = ACTION::LookupOK THEN
                                        "No." := Item_l."No.";
                                END;
                            "Item Type"::ProductGroup:
                                BEGIN
                                    ProductGroup_l.RESET;
                                    Actionl := PAGE.RUNMODAL(PAGE::"LSC Retail Product Groups", ProductGroup_l);
                                    IF Actionl = ACTION::LookupOK THEN
                                        "No." := ProductGroup_l.Code;
                                END;
                            "Item Type"::Category:
                                BEGIN
                                    Category_l.RESET;
                                    Actionl := PAGE.RUNMODAL(PAGE::"Item Categories", Category_l);
                                    IF Actionl = ACTION::LookupOK THEN
                                        "No." := Category_l.Code;
                                END;
                            "Item Type"::Division:
                                BEGIN
                                    Division_l.RESET;
                                    Actionl := PAGE.RUNMODAL(PAGE::"LSC Divisions", Division_l);
                                    IF Actionl = ACTION::LookupOK THEN
                                        "No." := Division_l.Code;
                                END;
                            "Item Type"::"Attribute 1",
                          "Item Type"::"Attribute 2",
                          "Item Type"::"Attribute 3":
                                BEGIN
                                    Atrributes_l.RESET;
                                    //Atrributes_l.SETRANGE(Atrributes_l."Attribute Type", Atrributes_l."Attribute Type"::Item);//REVISAR
                                    IF "Item Type" = "Item Type"::"Attribute 1" THEN
                                        Atrributes_l.SETRANGE(Atrributes_l."Attribute Code", AttributeSetup_l."Item Attrib. 1 Code")
                                    ELSE
                                        IF "Item Type" = "Item Type"::"Attribute 2" THEN
                                            Atrributes_l.SETRANGE(Atrributes_l."Attribute Code", AttributeSetup_l."Item Attrib. 2 Code")
                                        ELSE
                                            Atrributes_l.SETRANGE(Atrributes_l."Attribute Code", AttributeSetup_l."Item Attrib. 3 Code");
                                    Actionl := PAGE.RUNMODAL(PAGE::"LSC Attribute Options Lookup", Atrributes_l);
                                    IF Actionl = ACTION::LookupOK THEN
                                        "No." := Atrributes_l."Option Value";
                                END;
                            "Item Type"::SpecialGroup:
                                BEGIN
                                    SpecialGroup_l.RESET;
                                    Actionl := PAGE.RUNMODAL(PAGE::"LSC Special Groups", SpecialGroup_l);
                                    IF Actionl = ACTION::LookupOK THEN
                                        "No." := SpecialGroup_l.Code;
                                END;
                        END;
                    end;

                    trigger OnValidate()
                    begin
                        IF "Entry Type" = "Entry Type"::EcommerceItem THEN
                            IF ("No." <> '') OR ("No." <> xRec."No.") THEN
                                VALIDATE("Unit of Measure", '')
                            ELSE
                                Rec."Unit of Measure" := '';
                    end;
                }
                field("Unit of Measure"; "Unit of Measure")
                {
                    Enabled = NoUMEditable;
                    Visible = UnitofMeasureVisible;
                }
                field(IntegrationCode; "Unit of Measure")
                {
                    Caption = 'IntegrationCode';
                    Visible = IntegrationCodeVisible;
                }
                field("Line No."; "Line No.")
                {
                    Visible = LineNoVisible;
                }
                field(Quantity; Quantity)
                {
                    Caption = 'Limit Quantity';
                    Visible = QuantityVisible;
                }
                field(Description; Description)
                {
                    Editable = DescriptionEnabled;
                    Visible = DescriptionVisible;
                }
                field(Sort; Sort)
                {
                    Visible = SortVisible;
                }
                field("Source Type"; "Source Type")
                {
                    Editable = false;
                    Visible = SourceTypeVisible;

                    trigger OnValidate()
                    begin
                        IF "No." <> '' THEN
                            IF "Item Type" <> xRec."Item Type" THEN
                                ERROR(Txt2);
                    end;
                }
                field("Starting Date"; "Starting Date")
                {
                    Visible = StartingDateVisible;
                }
                field("Ending Date"; "Ending Date")
                {
                    Visible = EndingDateVisible;
                }
                field("Start Time"; Rec."Start Time")
                {
                    Visible = StartTimeVisible;
                }
                field("End Time"; Rec."End Time")
                {
                    Visible = StartTimeVisible;
                }
                field(ID; ID)
                {
                    Caption = 'Discount Group/ID';
                    Style = Strong;
                    StyleExpr = TRUE;
                    Visible = IDVisible;
                }
                field("Price Default"; "Price Default")
                {
                    Visible = PricesDiscountVisible;

                    trigger OnValidate()
                    begin
                        "Price Default" := ROUND("Price Default", 0.01);

                        "Price Inc. Disc. Default" := "Price Default" - ROUND("Price Default" * ("Discount Default" / 100), 0.01);
                    end;
                }
                field("Price Inc. Disc. Default"; "Price Inc. Disc. Default")
                {
                    Visible = PricesDiscountVisible;

                    trigger OnValidate()
                    begin
                        "Price Inc. Disc. Default" := ROUND("Price Inc. Disc. Default", 0.01);
                        "Discount Default" := ROUND((1 - ("Price Inc. Disc. Default" / "Price Default")) * 100, 1);
                    end;
                }
                field("Discount Default"; "Discount Default")
                {
                    Visible = PricesDiscountVisible;

                    trigger OnValidate()
                    begin
                        "Discount Default" := ROUND("Discount Default", 0.01);
                        "Price Inc. Disc. Default" := "Price Default" - ROUND("Price Default" * ("Discount Default" / 100), 0.01);
                    end;
                }
                field("Tag Discount Default"; "Tag Discount Default")
                {
                    Visible = PricesDiscountVisible;
                }
                field("Blocked Ecommerce"; "Blocked Ecommerce")
                {
                    Visible = EcommerceBlockVisible;
                }
                field("Free Text"; "Free Text")
                {
                    Caption = 'Free Text';
                    Visible = FreeTextVisible;
                }
                field("Hierarchy Parent Code"; "Hierarchy Parent Code")
                {
                    Visible = HierarchyParentCodeVisible;

                    trigger OnDrillDown()
                    var
                        PAGEHiearchy: Page "FSN Ecommerce Info Extend.";
                        Hierarchy: Record "FSN Item Info. Extend";
                    begin
                        CLEAR(PAGEHiearchy);
                        PAGEHiearchy.SetMode(3);
                        PAGEHiearchy.SetHierarchyCode("Hierarchy Parent Code");
                        Hierarchy.SETRANGE(Hierarchy."Entry Type", Hierarchy."Entry Type"::EcommerceHierarchy);
                        Hierarchy.SETRANGE(Hierarchy."Sub Type", Hierarchy."Sub Type"::ItemSetting);
                        Hierarchy.SETRANGE(Hierarchy."No.", "Hierarchy Parent Code");
                        IF Hierarchy.FIND('-') THEN
                            PAGEHiearchy.SetFilterHerarchyLevel(Hierarchy."Item Type")
                        ELSE
                            PAGEHiearchy.SetFilterHerarchyLevel(Hierarchy."Item Type"::ProductGroup);
                        PAGEHiearchy.RUN;
                    end;
                }
                field("Minimum Quantity Sale"; "Minimum Quantity Sale")
                {
                    Visible = FieldsEcommerceVisible;
                }
                field("Maximum Quantity Sale"; "Maximum Quantity Sale")
                {
                    Visible = FieldsEcommerceVisible;
                }
                field("Require Medical Document"; "Require Medical Document")
                {
                    Visible = FieldsEcommerceVisible;
                }
                field(BlockShowDiscount; "Require Medical Document")
                {
                    Caption = 'Block Show Discount';
                    Visible = BlockShowDiscVisible;
                }
                field(Reason; Reason)
                {
                    Visible = ReasonVisible;
                }
                field("Mark Code"; "Mark Code")
                {
                    Visible = MarkVisible;
                }
                field("Image Link"; "Image Link")
                {
                    Visible = ImageLinkVisible;
                }
                field(AccesRoute; "Free Text")
                {
                    Caption = 'AccesRoute';
                    Visible = AccesRouteVisible;
                }
            }
        }
    }

    actions
    {
        area(processing)
        {
            action("Ecommerce-Prices")
            {
                Caption = 'Ecommerce-Prices';
                Image = ContractPayment;
                Promoted = true;
                PromotedCategory = Category4;
                PromotedIsBig = true;
                Visible = ActionPrices;

                trigger OnAction()
                var
                    PAGEEcommercePrices: Page "FSN Ecommerce Info Extend.";
                begin
                    PAGEEcommercePrices.SetMode(5);
                    PAGEEcommercePrices.SetFilterItemUM("No.", "Unit of Measure");
                    PAGEEcommercePrices.RUN;
                end;
            }
            action(CreateTempVersion)
            {
                Caption = 'Create Temp.Version';
                Image = Apply;
                Promoted = true;
                PromotedCategory = Category4;
                PromotedIsBig = true;
                Visible = ActionCopyTempVisible;

                trigger OnAction()
                begin
                    INIT;
                    Rec := xRec;
                    "Source Type" := "Source Type"::CopyTemporary;
                    "Starting Date" := TODAY;
                    "Ending Date" := TODAY;
                    "Last Date Modify" := CURRENTDATETIME;
                    "Last User Modify" := USERID;
                    Rec2.RESET;
                    Rec2.SETCURRENTKEY("Entry Type", "Sub Type", "No.", "Unit of Measure", "Line No.");
                    Rec2.SETRANGE(Rec2."Entry Type", "Entry Type");
                    Rec2.SETRANGE(Rec2."Sub Type", "Sub Type");
                    Rec2.SETRANGE(Rec2."No.", "No.");
                    Rec2.SETRANGE(Rec2."Unit of Measure", "Unit of Measure");
                    Rec2.SETRANGE(Rec2."Line No.", 0, 99);//Max copy
                    IF "Entry Type" = "Entry Type"::EcommercePrices THEN BEGIN//For setup price
                        Rec2.SETRANGE(Rec2.ID, ID);
                    END;

                    IF Rec2.FIND('+') THEN
                        "Line No." := xRec."Line No." + 1;

                    Rec2.SETRANGE(Rec2."Source Type", Rec2."Source Type"::CopyTemporary);
                    IF Rec2.COUNT > 1 THEN
                        ERROR(Txt1);

                    INSERT(TRUE);
                end;
            }
            action("Inventory-Limit")
            {
                Caption = 'Inventory-Limit';
                Image = InventorySetup;
                Promoted = true;
                PromotedCategory = Category5;
                PromotedIsBig = true;
                Visible = ActionInventoryLimit;

                trigger OnAction()
                var
                    PAGEEcommercePrices: Page "FSN Ecommerce Info Extend.";
                begin
                    PAGEEcommercePrices.SetMode(2);
                    PAGEEcommercePrices.RUN;
                end;
            }
        }
        area(navigation)
        {
            action(Division)
            {
                Caption = 'Division';
                Image = BOM;
                Promoted = true;
                PromotedCategory = Category6;
                PromotedIsBig = true;
                Visible = ActionHierarcyGroupVisible;

                trigger OnAction()
                var
                    PAGEEcommercePrices: Page "FSN Ecommerce Info Extend.";
                begin
                    PAGEEcommercePrices.SetFilterHerarchyLevel("Item Type"::Division);
                    PAGEEcommercePrices.SetMode(3);
                    PAGEEcommercePrices.RUN;
                end;
            }
            action("Item Category")
            {
                Caption = 'Product Category';
                Image = BOM;
                Promoted = true;
                PromotedCategory = Category6;
                PromotedIsBig = true;
                Visible = ActionHierarcyGroupVisible;

                trigger OnAction()
                var
                    PAGEEcommercePrices: Page "FSN Ecommerce Info Extend.";
                begin
                    PAGEEcommercePrices.SetFilterHerarchyLevel("Item Type"::Category);
                    PAGEEcommercePrices.SetMode(3);
                    PAGEEcommercePrices.RUN;
                end;
            }
            action("Product Group")
            {
                Caption = 'Product Group';
                Image = BOM;
                Promoted = true;
                PromotedCategory = Category6;
                PromotedIsBig = true;
                Visible = ActionHierarcyGroupVisible;

                trigger OnAction()
                var
                    PAGEEcommercePrices: Page "FSN Ecommerce Info Extend.";
                begin
                    PAGEEcommercePrices.SetFilterHerarchyLevel("Item Type"::ProductGroup);
                    PAGEEcommercePrices.SetMode(3);
                    PAGEEcommercePrices.RUN;
                end;
            }
            action(AddImage)
            {
                Caption = 'Extra Image';
                Image = ExplodeRouting;
                Promoted = true;
                PromotedCategory = Category7;
                PromotedIsBig = true;
                Visible = ImageLinkVisible;

                trigger OnAction()
                var
                    PAGEEcommercePrices: Page "FSN Ecommerce Info Extend.";
                begin
                    PAGEEcommercePrices.SetMode("Entry Type");
                    PAGEEcommercePrices.SetFilterHerarchyLevel("Item Type");
                    PAGEEcommercePrices.SetFilterItemUM("No.", '');
                    PAGEEcommercePrices.SetSubTypeMode(InformationRec."Sub Type"::ItemImage);
                    PAGEEcommercePrices.SetCurrLine("Line No.");
                    PAGEEcommercePrices.SetCurrID(ID);
                    PAGEEcommercePrices.RUN;
                end;
            }
            action(Add)
            {
                Image = Add;
                Promoted = true;
                PromotedCategory = Category7;
                PromotedIsBig = true;
                Visible = ActionAdd;

                trigger OnAction()
                var
                    Item_l: Record "Item";
                begin
                    IF NOT ("Sub Type" = "Sub Type"::ItemImage) THEN
                        EXIT;

                    OldRec.RESET;
                    OldRec.SETRANGE(OldRec."Entry Type", InformationRec."Entry Type");
                    OldRec.SETRANGE(OldRec."Sub Type", OldRec."Sub Type"::ItemSetting);
                    OldRec.SETRANGE(OldRec."No.", InformationRec."No.");
                    OldRec.FIND('-');

                    Rec.INIT;
                    "Entry Type" := InformationRec."Entry Type";
                    "Sub Type" := "Sub Type"::ItemImage;
                    "No." := OldRec."No.";
                    "Unit of Measure" := '';
                    ID := InformationRec.ID;
                    IF ("Entry Type" = "Entry Type"::ItemInformation) AND Item_l.GET("No.") THEN
                        Description := Item_l.Description
                    ELSE
                        Description := OldRec.Description;
                    "Item Type" := OldRec."Item Type";

                    Rec2.RESET;
                    Rec2.SETCURRENTKEY("Entry Type", "Sub Type", "No.", "Unit of Measure", "Line No.");
                    Rec2.SETRANGE(Rec2."Entry Type", InformationRec."Entry Type");
                    Rec2.SETRANGE(Rec2."Sub Type", "Sub Type"::ItemImage);
                    Rec2.SETRANGE(Rec2."No.", OldRec."No.");
                    IF Rec2.FIND('+') THEN
                        "Line No." := Rec2."Line No." + 1
                    ELSE
                        "Line No." := 0;


                    Rec2.SETRANGE(Rec2.ID, InformationRec.ID);
                    IF Rec2.COUNT > 9 THEN
                        ERROR(Txt3);

                    INSERT(TRUE);
                end;
            }
            action(AddItemLink)
            {
                Caption = 'Add Item Link';
                Image = Item;
                Promoted = true;
                PromotedCategory = Category7;
                PromotedIsBig = true;
                Visible = ActionItemLinkVisible;

                trigger OnAction()
                var
                    PAGEEcommercePrices: Page "FSN Ecommerce Info Extend.";
                begin
                    PAGEEcommercePrices.SetMode("Entry Type");
                    PAGEEcommercePrices.SetSubTypeMode("Sub Type"::ItemLink);
                    PAGEEcommercePrices.SetFilterHerarchyLevel("Item Type");
                    PAGEEcommercePrices.SetFilterItemUM("No.", "Unit of Measure");
                    PAGEEcommercePrices.SetCurrLine("Line No.");
                    PAGEEcommercePrices.SetCurrID(ID);
                    PAGEEcommercePrices.RUN;
                end;
            }
            action("Global Setup")
            {
                Caption = 'Global Setup';
                Image = SetupLines;
                Promoted = true;
                PromotedCategory = Category7;
                PromotedIsBig = true;
                Visible = ActionGlobalSetupVisible;

                trigger OnAction()
                var
                    PAGEEcommercePrices: Page "FSN Ecommerce Info Extend.";
                begin
                    PAGEEcommercePrices.SetMode("Entry Type"::Parameters);
                    PAGEEcommercePrices.SetSubTypeMode("Sub Type"::ItemSetting);
                    PAGEEcommercePrices.RUN;
                end;
            }
        }
    }

    trigger OnInit()
    begin
        InitVisibleControls(TRUE);

        ActionCopyTempVisible := TRUE;
        ActionPrices := FALSE;
        ActionInventoryLimit := FALSE;
        ActionHierarcyGroupVisible := FALSE;
        ActionAdd := FALSE;
        ActionItemLinkVisible := FALSE;
        ActionGlobalSetupVisible := FALSE;

        RetailSetup.GET;
        CLEAR(InformationRec);
        InformationRec.INIT;
    end;

    trigger OnNewRecord(BelowxRec: Boolean)
    begin
        ID := xRec.ID;
        "Item Type" := xRec."Item Type";
        IF InformationRec."Sub Type" = InformationRec."Sub Type"::ItemImage THEN BEGIN
            "Item Type" := InformationRec."Item Type";
            ID := InformationRec.ID;
        END;
        IF InformationRec."Sub Type" = InformationRec."Sub Type"::ItemLink THEN BEGIN
            "Item Type" := InformationRec."Item Type";
            "No." := InformationRec."No.";
            ID := InformationRec."Unit of Measure";
            "Line No." := InformationRec."Line No.";
        END;
        IF InformationRec."Entry Type" = InformationRec."Entry Type"::EcommerceLimit THEN
            "Item Type" := 0;
    end;

    trigger OnOpenPage()
    var
        ItemInfo_l: Record "FSN Item Info. Extend";
    begin
        FILTERGROUP(2);
        SETRANGE("Entry Type", InformationRec."Entry Type");
        CASE InformationRec."Entry Type" OF
            InformationRec."Entry Type"::EcommerceLimit,
            InformationRec."Entry Type"::EcommerceHierarchy,
            InformationRec."Entry Type"::EcommerceItem,
            InformationRec."Entry Type"::EcommercePrices:
                BEGIN
                    SETRANGE("Sub Type", "Sub Type"::ItemSetting);
                    IF InformationRec."Sub Type" = InformationRec."Sub Type"::ItemImage THEN BEGIN
                        SETRANGE("Sub Type", "Sub Type"::ItemImage);
                        SETRANGE("Item Type", InformationRec."Item Type");
                    END;
                    IF InformationRec."Sub Type" = InformationRec."Sub Type"::ItemLink THEN BEGIN
                        SETRANGE("Sub Type", InformationRec."Sub Type");
                    END;

                    QuantityVisible := FALSE;
                    SubTypeVisible := FALSE;
                    LineNoVisible := FALSE;
                    SortVisible := FALSE;
                END;
            InformationRec."Entry Type"::Parameters:
                BEGIN
                    //Nothing filter
                END ELSE
                        SETRANGE("Sub Type", "Sub Type"::Information);
        END;
        FILTERGROUP(0);

        IF InformationRec."No." <> '' THEN
            SETRANGE("No.", InformationRec."No.");
        IF InformationRec."Item Type" = 0 THEN
            IF InformationRec."Unit of Measure" <> '' THEN
                SETRANGE("Unit of Measure", InformationRec."Unit of Measure");
        IF InformationRec."Item Type" > 0 THEN
            SETRANGE("Item Type", InformationRec."Item Type");

        CASE InformationRec."Sub Type" OF
            InformationRec."Sub Type"::ItemLink:
                BEGIN
                    InitVisibleControls(FALSE);
                    MarkVisible := TRUE;
                    EntryTypeVisible := TRUE;
                    SubTypeVisible := TRUE;
                    NoVisible := TRUE;
                    NoUMEditable := TRUE;
                    DescriptionVisible := TRUE;
                    ItemTypeVisible := TRUE;
                    BlockShowDiscVisible := FALSE;
                    AccesRouteVisible := FALSE;
                    StartingDateVisible := TRUE;
                    StartTimeVisible := TRUE;
                    EndingDateVisible := TRUE;
                    EndTimeVisible := TRUE;
                    IDVisible := TRUE;
                END;
            InformationRec."Sub Type"::ItemImage:
                BEGIN
                    InitVisibleControls(FALSE);
                    IntegrationCodeVisible := FALSE;
                    IDVisible := TRUE;
                    EntryTypeVisible := TRUE;
                    SubTypeVisible := TRUE;
                    NoVisible := TRUE;
                    NoUMEditable := TRUE;
                    DescriptionVisible := TRUE;
                    ItemTypeVisible := TRUE;
                    BlockShowDiscVisible := FALSE;
                    ActionAdd := TRUE;
                    ActionCopyTempVisible := FALSE;
                    ImageLinkVisible := TRUE;
                    AccesRouteVisible := FALSE;
                END;
            ELSE
                CASE InformationRec."Entry Type" OF
                    InformationRec."Entry Type"::EcommerceLimit:
                        BEGIN
                            ItemTypeEditable := TRUE;
                            FieldsEcommerceVisible := FALSE;
                            SortVisible := FALSE;
                            ReasonVisible := FALSE;
                            HierarchyParentCodeVisible := FALSE;
                            PricesDiscountVisible := FALSE;
                            IDVisible := FALSE;
                            QuantityVisible := TRUE;
                            ImageLinkVisible := FALSE;

                            ActionPrices := FALSE;
                        END;
                    InformationRec."Entry Type"::EcommerceHierarchy:
                        BEGIN
                            UnitofMeasureVisible := FALSE;
                            FieldsEcommerceVisible := FALSE;
                            MarkVisible := FALSE;
                            PricesDiscountVisible := FALSE;
                            ActionPrices := FALSE;
                            IDVisible := FALSE;
                            IntegrationCodeVisible := TRUE;
                            ImageLinkVisible := TRUE;

                            IF InformationRec."Hierarchy Parent Code" <> '' THEN BEGIN
                                ItemInfo_l.RESET;
                                ItemInfo_l.SETRANGE(ItemInfo_l."Entry Type", ItemInfo_l."Entry Type"::EcommerceHierarchy);
                                ItemInfo_l.SETRANGE(ItemInfo_l."Sub Type", ItemInfo_l."Sub Type"::ItemSetting);
                                ItemInfo_l.SETRANGE(ItemInfo_l."No.", InformationRec."Hierarchy Parent Code");
                                IF ItemInfo_l.FINDFIRST THEN BEGIN
                                    Rec := ItemInfo_l;
                                    IF ItemInfo_l."Item Type" = ItemInfo_l."Item Type"::Division THEN
                                        HierarchyParentCodeVisible := FALSE;
                                END;
                            END;
                            BlockShowDiscVisible := TRUE;
                            DescriptionEnabled := TRUE;
                            IF InformationRec."Sub Type" <> InformationRec."Sub Type"::ItemLink THEN
                                ActionItemLinkVisible := TRUE;
                        END;
                    InformationRec."Entry Type"::EcommerceItem:
                        BEGIN
                            ActionPrices := TRUE;
                            ActionHierarcyGroupVisible := TRUE;
                            ActionInventoryLimit := TRUE;
                            ActionGlobalSetupVisible := TRUE;
                        END;
                    InformationRec."Entry Type"::EcommercePrices:
                        BEGIN
                            FieldsEcommerceVisible := FALSE;
                            ImageLinkVisible := TRUE;
                        END;
                    InformationRec."Entry Type"::Parameters:
                        BEGIN
                            InitVisibleControls(FALSE);
                            EntryTypeVisible := TRUE;
                            SubTypeVisible := TRUE;
                            NoUMEditable := TRUE;
                            NoVisible := TRUE;
                            AccesRouteVisible := FALSE;
                            BlockShowDiscVisible := FALSE;
                            StartingDateVisible := TRUE;
                            StartTimeVisible := TRUE;
                            EndingDateVisible := TRUE;
                            EndTimeVisible := TRUE;
                            IDVisible := TRUE;
                            FreeTextVisible := TRUE;
                            ReasonVisible := TRUE;

                            SubTypeEditable := TRUE;

                            ActionCopyTempVisible := FALSE;
                        END;
                END;
        END;
    end;

    var
        FieldsEcommerceVisible: Boolean;
        EntryTypeVisible: Boolean;
        SubTypeVisible: Boolean;
        SubTypeEditable: Boolean;
        NoVisible: Boolean;
        NoUMEditable: Boolean;
        IDVisible: Boolean;
        UnitofMeasureVisible: Boolean;
        LineNoVisible: Boolean;
        QuantityVisible: Boolean;
        DescriptionVisible: Boolean;
        DescriptionEnabled: Boolean;
        FreeTextVisible: Boolean;
        SortVisible: Boolean;
        ReasonVisible: Boolean;
        StartingDateVisible: Boolean;
        StartTimeVisible: Boolean;
        EndingDateVisible: Boolean;
        EndTimeVisible: Boolean;
        SourceTypeVisible: Boolean;
        ItemTypeVisible: Boolean;
        ItemTypeEditable: Boolean;
        HierarchyParentCodeVisible: Boolean;
        MarkVisible: Boolean;
        EcommerceBlockVisible: Boolean;
        BlockShowDiscVisible: Boolean;
        ImageLinkVisible: Boolean;
        AccesRouteVisible: Boolean;
        IntegrationCodeVisible: Boolean;
        InformationRec: Record "FSN Item Info. Extend";
        Rec2: Record "FSN Item Info. Extend";
        OldRec: Record "FSN Item Info. Extend";
        LineTxt: Text[50];
        LineNo: Integer;
        MinSaleVisible: Boolean;
        MaxSaleBisible: Boolean;
        PricesDiscountVisible: Boolean;
        ActionCopyTempVisible: Boolean;
        ActionPrices: Boolean;
        Txt1: Label 'Can be only 2 copy temporary by item';
        ActionInventoryLimit: Boolean;
        Txt2: Label 'Cant be change "Item Type", must be delete and new create';
        ActionHierarcyGroupVisible: Boolean;
        ActionAdd: Boolean;
        ActionItemLinkVisible: Boolean;
        ActionGlobalSetupVisible: Boolean;
        RetailSetup: Record "LSC Retail Setup";
        Txt3: Label 'Limit image is 10';
        H_inicio: Time;
        H_Fin: Time;


    procedure SetMode(pModeOption: Integer)
    begin
        InformationRec."Entry Type" := pModeOption;
    end;


    procedure SetFilterItemUM(No: Code[20]; UM: Code[10])
    begin
        InformationRec."No." := No;
        InformationRec."Unit of Measure" := UM;
    end;


    procedure SetFilterHerarchyLevel(pItemTypeInt: Integer)
    begin
        InformationRec."Item Type" := pItemTypeInt;
    end;


    procedure SetHierarchyCode(pCode: Code[30])
    begin
        InformationRec."Hierarchy Parent Code" := pCode;
    end;


    procedure SetSubTypeMode(pSubTypeMode: Integer)
    begin
        InformationRec."Sub Type" := pSubTypeMode;
    end;


    procedure SetCurrLine(pCurrLine: Integer)
    begin
        InformationRec."Line No." := pCurrLine;
    end;


    procedure SetCurrID(pCurrID: Code[20])
    begin
        InformationRec.ID := pCurrID;
    end;


    procedure InitVisibleControls(pVisible: Boolean)
    begin
        FieldsEcommerceVisible := pVisible;
        MarkVisible := pVisible;
        EntryTypeVisible := pVisible;
        SubTypeVisible := pVisible;
        NoVisible := pVisible;
        IDVisible := pVisible;
        UnitofMeasureVisible := pVisible;
        LineNoVisible := pVisible;
        QuantityVisible := pVisible;
        DescriptionVisible := pVisible;
        DescriptionEnabled := pVisible;
        FreeTextVisible := pVisible;
        SortVisible := pVisible;
        ReasonVisible := pVisible;
        StartingDateVisible := pVisible;
        EndingDateVisible := pVisible;
        StartTimeVisible := pVisible;
        EndTimeVisible := pVisible;
        SourceTypeVisible := pVisible;
        ItemTypeVisible := pVisible;
        HierarchyParentCodeVisible := pVisible;
        PricesDiscountVisible := pVisible;
        EcommerceBlockVisible := pVisible;
        BlockShowDiscVisible := NOT pVisible;
        ImageLinkVisible := pVisible;
        AccesRouteVisible := NOT pVisible;

        NoUMEditable := pVisible;
        ItemTypeEditable := NOT pVisible;
        IntegrationCodeVisible := NOT pVisible;
        SubTypeEditable := NOT pVisible;
    end;
}


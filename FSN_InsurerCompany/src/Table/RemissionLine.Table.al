table 50057 "FSN Remission Line"
{
    Caption = 'Remission Line';
    PasteIsValid = false;

    fields
    {
        field(10; "Document Type"; Option)
        {
            Caption = 'Document Type';
            OptionMembers = Remision;
        }
        field(20; "Document No."; Code[20])
        {
            Caption = 'Document No.';
        }
        field(30; "Line No."; Integer)
        {
            Caption = 'Line No.';
        }
        field(40; Type; Option)
        {
            Caption = 'Type';
            OptionCaption = 'Item,Coinsurance,Deductible,Comission';
            OptionMembers = Item,Coinsurance,Deductible,Comission;
        }
        field(50; "No."; Code[20])
        {
            TableRelation = IF (Type = CONST(Item)) Item."No.";

            trigger OnValidate()
            begin
                Item.GET("No.");
                IF Description = '' THEN
                    Description := Item.Description;

                IF ("Unit of Measure" = '') OR NOT (ItemUnitOfMeasure.GET("No.", "Unit of Measure")) THEN
                    "Unit of Measure" := Item."Sales Unit of Measure";

                RemissionHeader.GET("Document Type", "Document No.");
                "Store No." := RemissionHeader."Store No.";
            end;
        }
        field(60; Barcode; Code[20])
        {
            Caption = 'Barcode';
            TableRelation = "LSC Barcodes"."Barcode No.";

            trigger OnValidate()
            var
                ws: Codeunit "FSN WS XML Remss. Integration";
            begin
                Barcodes.GET(Barcode);
                Item.GET(Barcodes."Item No.");
                ErrorText := '';

                RemissionHeader.GET("Document Type", "Document No.");
                IF not ws.ProdIsMInsal(Item."No.") THEN
                    IF AllowDenyItemTable.IsExcludeItemForCustomer(RemissionHeader."Customer No.", RemissionHeader."Company No.",
                      Item."No.", 0, ErrorText) THEN
                        ERROR(ErrorText);

                "No." := Item."No.";
                Barcodes.TESTFIELD("Unit of Measure Code");
                "Unit of Measure" := Barcodes."Unit of Measure Code";
                Description := Barcodes.Description;
                VALIDATE("Unit of Measure");
                "Store No." := RemissionHeader."Store No.";

            end;
        }
        field(70; Recipe; Code[20])
        {
            Caption = 'Recipe';
        }
        field(80; Description; Text[50])
        {
            Caption = 'Description';
        }
        field(90; "Unit of Measure"; Code[10])
        {
            Caption = 'Unit of Measure';
            TableRelation = "Item Unit of Measure".Code WHERE("Item No." = FIELD("No."));

            trigger OnValidate()
            begin
                ItemUnitOfMeasure.GET("No.", "Unit of Measure");
                "Qty. Per Unit of Measure" := ItemUnitOfMeasure."Qty. per Unit of Measure";
                VALIDATE(Quantity);
            end;
        }
        field(100; Quantity; Decimal)
        {
            Caption = 'Quantity';
            MaxValue = 5000;
            MinValue = 0;

            trigger OnValidate()
            var
                VATPercent: Decimal;
                VATPostSetup: Record "VAT Posting Setup";
                VATBusPosting: Code[10];
                lCustomer: Record Customer;
                lPrice: Decimal;
                lineDisc: Decimal;
            begin
                IF Type <> Type::Item THEN
                    ERROR(STRSUBSTNO(Text002, FORMAT(Type)));
                Initialize();
                LineDiscountReturn := 0;
                PriceGlobalBeforeDisc := 0;
                PriceGlobalAfterDisc := 0;

                RemissionHeader.GET("Document Type", "Document No.");//1

                /*
                RemissionHeader.TestField("Customer No.");

                Clear(lPrice);
                lPrice := RetailPriceUtils.GetStandardCustomerPrice(RemissionHeader."Customer No.", Rec."No.", '',
                                                Rec."Unit of Measure", Rec.Quantity, Today(), '', lineDisc);
                
                //

                Item.Get(Rec."No.");
                if not PosFuncProfile."No VAT Used" and not PosFuncProfile."Add VAT to Prices" then
                    if Customer."VAT Bus. Posting Group" <> '' then
                        lPrice := RetailPriceUtils.CalcPriceInclVat(Item, lPrice, Customer."Vat Bus. Posting Group")
                    else
                        lPrice := RetailPriceUtils.CalcPriceInclVat(Item, lPrice, Store."Store VAT Bus. Post. Gr.");

                lPrice := Round(lPrice, PosFuncProfile."Price Rounding to");

                "Unit Cost (LCY)" := Item."Unit Cost" * Rec."Qty. Per Unit of Measure";
                "Discount %" := lineDisc;
                */
                /******** old version ***********/

                PriceGlobalAfterDisc :=
                    GetStandardCustomerPrice(RemissionHeader."Customer No.", Rec."No.", '',
                                        Rec."Unit of Measure", Rec.Quantity, TODAY, '', LineDiscountReturn, PriceGlobalBeforeDisc); //Currency Code

                "Unit Cost (LCY)" := Item."Unit Cost";
                "Discount %" := LineDiscountReturn;
                PriceGlobalBeforeDiscExcVAT := ROUND(PriceGlobalBeforeDisc, PosFuncProfile."Amount Rounding to");
                PriceGlobalAfterDiscExcVAT := ROUND(PriceGlobalAfterDisc, PosFuncProfile."Amount Rounding to");

                VATPercent := 0;
                VATBusPosting := '';
                RemissionHeader.GET("Document Type", "Document No.");
                CompanyInsurer.GET(RemissionHeader."Company No.");
                Item.GET("No.");
                VATBusPosting := Store."Store VAT Bus. Post. Gr.";

                if VATBusPosting <> '' then
                    IF RemissionHeader."Customer No." <> '' THEN
                        IF Customer.GET(RemissionHeader."Customer No.") THEN
                            VATBusPosting := lCustomer."VAT Bus. Posting Group";
                IF VATBusPosting = '' THEN
                    VATBusPosting := Item."VAT Bus. Posting Gr. (Price)";

                IF CompanyInsurer."Price Formula" = CompanyInsurer."Price Formula"::Standar THEN BEGIN
                    IF NOT (PosFuncProfile."No VAT Used") AND NOT (PosFuncProfile."Add VAT to Prices") THEN BEGIN
                        PriceGlobalBeforeDisc := RetailPriceUtils.CalcPriceInclVat(Item, PriceGlobalBeforeDisc, VATBusPosting);
                        PriceGlobalAfterDisc := RetailPriceUtils.CalcPriceInclVat(Item, PriceGlobalAfterDisc, VATBusPosting);

                        IF VATPostSetup.GET(VATBusPosting, Item."VAT Prod. Posting Group") THEN
                            IF VATPostSetup."VAT Calculation Type" = VATPostSetup."VAT Calculation Type"::"Normal VAT" THEN
                                VATPercent := VATPostSetup."VAT %";

                    END;
                    PriceGlobalBeforeDisc := ROUND(PriceGlobalBeforeDisc, PosFuncProfile."Amount Rounding to");
                    PriceGlobalAfterDisc := ROUND(PriceGlobalAfterDisc, PosFuncProfile."Amount Rounding to");

                    "Amount Including VAT" := PriceGlobalAfterDisc * Quantity;
                    Amount := "Amount Including VAT" / (1 + (VATPercent / 100));
                    "VAT Amount" := "Amount Including VAT" - Amount;
                    "Discount Amount" := -("Amount Including VAT" - (PriceGlobalBeforeDisc * Quantity));

                    "Unit Price" := PriceGlobalBeforeDiscExcVAT;
                    "Unit Price Inc. VAT" := PriceGlobalBeforeDisc;

                END ELSE BEGIN
                    VATPercent := 0;
                    IF VATPostSetup.GET(VATBusPosting, Item."VAT Prod. Posting Group") THEN
                        IF VATPostSetup."VAT Calculation Type" = VATPostSetup."VAT Calculation Type"::"Normal VAT" THEN
                            VATPercent := VATPostSetup."VAT %";

                    Amount := ROUND((PriceGlobalBeforeDiscExcVAT * (1 - (LineDiscountReturn / 100))) * Quantity, PosFuncProfile."Amount Rounding to");
                    "Discount Amount" := (PriceGlobalBeforeDiscExcVAT * (LineDiscountReturn / 100)) * Quantity;
                    "Discount Amount" := "Discount Amount" * (1 + (VATPercent / 100));
                    //Form A Line x Line
                    "Amount Including VAT" := Amount * (1 + (VATPercent / 100));
                    "VAT Amount" := "Amount Including VAT" - Amount;

                    "Unit Price" := PriceGlobalBeforeDiscExcVAT;
                    PriceGlobalBeforeDisc := PriceGlobalBeforeDisc * (1 + (VATPercent / 100));
                    PriceGlobalBeforeDisc := ROUND(PriceGlobalBeforeDisc, PosFuncProfile."Amount Rounding to");
                    "Unit Price Inc. VAT" := PriceGlobalBeforeDisc;

                END;
            end;
        }
        field(110; "Unit Price"; Decimal)
        {
            Caption = 'Unit Price';
        }
        field(115; "Unit Price Inc. VAT"; Decimal)
        {
            Caption = 'Unit Price Inc. VAT';

            trigger OnValidate()
            begin
                Initialize;
                Item.GET("No.");
                "Unit Price Inc. VAT" := ROUND("Unit Price Inc. VAT", PosFuncProfile."Amount Rounding to");

                IF NOT VATPostingSetup.GET(Item."VAT Bus. Posting Gr. (Price)", Item."VAT Prod. Posting Group") THEN
                    VATPostingSetup.INIT;

                CASE VATPostingSetup."VAT Calculation Type" OF
                    VATPostingSetup."VAT Calculation Type"::"Reverse Charge VAT":
                        VATPostingSetup."VAT %" := 0;
                    VATPostingSetup."VAT Calculation Type"::"Sales Tax":
                        ERROR(
                          Text99001450 +
                          Text99001451, VATPostingSetup.FIELDCAPTION("VAT Calculation Type"),
                          VATPostingSetup."VAT Calculation Type");
                END;

                "Unit Price" := ROUND("Unit Price Inc. VAT" / (1 + (VATPostingSetup."VAT %" / 100)), PosFuncProfile."Amount Rounding to");

                "Unit Cost (LCY)" := Item."Unit Cost";
                "Discount %" := 0;
                "Discount Amount" := 0;
                Amount := "Unit Price" * Quantity;
                "Amount Including VAT" := "Unit Price Inc. VAT" * Quantity;
                "VAT Amount" := "Amount Including VAT" - Amount;
            end;

        }
        field(120; "Unit Cost (LCY)"; Decimal)
        {
            Caption = 'Unit Cost (LCY)';
        }
        field(130; "VAT Amount"; Decimal)
        {
            Caption = 'VAT Amount';
        }
        field(140; "Discount %"; Decimal)
        {
            Caption = 'Discount %';
        }
        field(150; "Discount Amount"; Decimal)
        {
            Caption = 'Discount Amount';
        }
        field(160; Amount; Decimal)
        {
            Caption = 'Amount';
        }
        field(170; "Amount Including VAT"; Decimal)
        {
            Caption = 'Amount Including VAT';
        }
        field(180; "Store No."; Code[10])
        {
            Caption = 'Store No.';
            TableRelation = "LSC Store"."No.";
        }
        field(190; "Receipt No. Coinsurance"; Code[20])
        {
        }
        field(200; "Receipt No. Closed"; Code[20])
        {
        }
        field(210; "POS Terminal No. Coinsurance"; Code[10])
        {
            TableRelation = "LSC POS Terminal"."No.";
        }
        field(220; "POS Terminal No. Closed"; Code[10])
        {
            TableRelation = "LSC POS Terminal"."No.";
        }
        field(230; "Transaction No. Coinsurance"; Integer)
        {
        }
        field(240; "Transaction No. Closed"; Integer)
        {
        }
        field(250; "Line No. Closed"; Integer)
        {
        }
        field(260; "Qty. Per Unit of Measure"; Decimal)
        {
        }
        field(270; Scanned; Boolean)
        {
            Caption = 'Scanned';
        }
        field(1100; "Replication Counter"; Integer)
        {

            trigger OnValidate()
            begin
                RemissionLine.RESET;
                RemissionLine.SETCURRENTKEY("Replication Counter");
                IF RemissionLine.FINDLAST THEN
                    "Replication Counter" := RemissionLine."Replication Counter" + 1
                ELSE
                    "Replication Counter" := 1;
            end;
        }
        field(1200; Lot; Code[50])
        {
            Caption = 'Lot';
        }

        field(1300; "Expiration Date"; Date)
        {
            Caption = 'Expiration Date';
        }
    }

    keys
    {
        key(Key1; "Document Type", "Document No.", "Line No.")
        {
            Clustered = true;
        }
        key(Key2; Type, "Line No.")
        {
        }
        key(Key3; "Document Type", "Document No.", Type)
        {
            SumIndexFields = "Amount Including VAT";
        }
        key(Key4; "Store No.", "Receipt No. Coinsurance", "POS Terminal No. Coinsurance", "Transaction No. Coinsurance")
        {
        }
        key(Key5; "Store No.", "Receipt No. Closed", "POS Terminal No. Closed", "Transaction No. Closed", "Line No. Closed")
        {
        }
        key(Key6; "Replication Counter")
        {
        }
    }

    fieldgroups
    {
    }

    trigger OnDelete()
    begin
        IF RemissionHeader.GET("Document Type", "Document No.") THEN
            IF RemissionHeader.Status <> RemissionHeader.Status::Pending THEN
                ERROR(STRSUBSTNO(Text003, FORMAT(RemissionHeader.Status)));
        //CreateAction(2);
    end;

    trigger OnInsert()
    var
        Item: Record Item;
    begin
        NextLine.RESET;
        NextLine.SETRANGE(NextLine."Document Type", "Document Type");
        NextLine.SETRANGE(NextLine."Document No.", "Document No.");
        IF NextLine.FINDLAST THEN
            "Line No." := NextLine."Line No." + 10000
        ELSE
            "Line No." := 10000;

        IF Type = Type::Item THEN BEGIN
            RemissionHeader.GET("Document Type", "Document No.");
            CompanyInsurer.GET(RemissionHeader."Company No.");
            IF (Recipe = '') AND CompanyInsurer."Recipe By Line" THEN
                ERROR(STRSUBSTNO(Text004, CompanyInsurer.Description));
        END;
        if Item.Get("No.") and not (Item."LSC Attrib 1 Code" = 'LICITACION') then begin
            IF BOUtil.IsBlockSaleOnPOS("No.", '', '', "Store No.", '', TODAY, ItemStatusLink) THEN
                ERROR(STRSUBSTNO(Text005, ItemStatusLink."Status Code"));
        end;

        //CreateAction(0);
    end;

    trigger OnModify()
    begin
        RemissionHeader.GET("Document Type", "Document No.");
        CompanyInsurer.GET(RemissionHeader."Company No.");
        IF (Recipe = '') AND CompanyInsurer."Recipe By Line" THEN
            ERROR(STRSUBSTNO(Text004, CompanyInsurer.Description));

        //CreateAction(1);
    end;

    trigger OnRename()
    begin
        //CreateAction(3);
    end;


    var
        Barcodes: Record "LSC Barcodes";
        Item: Record Item;
        NextLine: Record "FSN Remission Line";
        ItemUnitOfMeasure: Record "Item Unit of Measure";
        SalesPriceMgt: Codeunit "Sales Price Calc. Mgt.";
        RemissionHeader: Record "FSN Remission Header";
        RemissionLine: Record "FSN Remission Line";
        Customer: Record Customer;
        CompanyInsurer: Record "FSN Company Insurer";
        Store: Record "LSC Store";
        LineDiscountReturn: Decimal;
        PosFuncProfile: Record "LSC POS Func. Profile";
        GLSetup: Record "General Ledger Setup";
        RetailPriceUtils: Codeunit "LSC Retail Price Utils";
        BOUtil: Codeunit "LSC BO Utils";
        PriceGlobalBeforeDisc: Decimal;
        PriceGlobalAfterDisc: Decimal;
        PriceGlobalBeforeDiscExcVAT: Decimal;
        PriceGlobalAfterDiscExcVAT: Decimal;
        VATPostingSetup: Record "VAT Posting Setup";
        Text99001450: Label 'Prices including VAT cannot be calculated when ';
        Text99001451: Label '%1 is %2.';
        Text002: Label 'Cant be modify quantity type %1';
        Text003: Label 'Header is status %1  line cant be delete';
        AllowDenyItemTable: Record "FSN Allow/Deny Item Customer";
        ItemStatusLink: Record "LSC Item Status Link";
        ErrorText: Text;
        Text004: Label 'Company %1 require Recipe by line';
        Text005: Label 'Item block for sale on POS. Status: %1';


    procedure Initialize()
    begin

        RemissionHeader.GET("Document Type", "Document No.");
        Store.GET(RemissionHeader."Store No.");
        PosFuncProfile.GET(Store."Functionality Profile");
        GLSetup.GET;
        TESTFIELD("No.");
        TESTFIELD("Unit of Measure");

    end;

    procedure GetStandardCustomerPrice(CustomerNo: Code[20]; ItemNo: Code[20]; VariantCode: Code[20]; UOM: Code[20]; SalesQuantity: Decimal; DateValid: Date; CurrencyCode: Code[10]; var LineDisc: Decimal; var PriceBeforeDisc: decimal) UnitPrice: Decimal
    var
        SalesHeaderTmp: Record "Sales Header" temporary;
        SalesLineTmp: Record "Sales Line" temporary;
        Item: Record Item;
        Customer: Record Customer;
        ItemUnitofMeasure: Record "Item Unit of Measure";
        CurrExchRate: Record "Currency Exchange Rate";
        Proceed: Boolean;
    begin
        //GetStandardCustomerPrice
        GLSetup.Get;

        if Customer.Get(CustomerNo) then begin
            Item.Get(ItemNo);
            SalesHeaderTmp.Init;
            SalesHeaderTmp."Document Type" := SalesHeaderTmp."Document Type"::Invoice;
            SalesHeaderTmp."Sell-to Customer No." := CustomerNo;
            SalesHeaderTmp."Bill-to Customer No." := CustomerNo;
            SalesHeaderTmp."Posting Date" := DateValid;
            SalesHeaderTmp."Currency Code" := CurrencyCode;
            SalesHeaderTmp."Currency Factor" := CurrExchRate.ExchangeRate(DateValid, CurrencyCode);
            SalesHeaderTmp."VAT Bus. Posting Group" := Item."VAT Bus. Posting Gr. (Price)";

            SalesLineTmp.Init;
            SalesLineTmp.Type := SalesLineTmp.Type::Item;
            SalesLineTmp."No." := ItemNo;
            SalesLineTmp."Variant Code" := VariantCode;
            SalesLineTmp."Customer Price Group" := Customer."Customer Price Group";
            SalesLineTmp."Customer Disc. Group" := Customer."Customer Disc. Group";
            SalesLineTmp.Quantity := Abs(SalesQuantity);
            SalesLineTmp."Unit of Measure Code" := UOM;
            if ItemUnitofMeasure.Get(ItemNo, UOM) then
                SalesLineTmp."Qty. per Unit of Measure" := ItemUnitofMeasure."Qty. per Unit of Measure"
            else
                SalesLineTmp."Qty. per Unit of Measure" := 1;
            SalesLineTmp."Allow Invoice Disc." := true;
            SalesLineTmp."Allow Line Disc." := true;
            SalesPriceMgt.FindSalesLinePrice(SalesHeaderTmp, SalesLineTmp, 0);
            UnitPrice := SalesLineTmp."Unit Price";
            PriceBeforeDisc := UnitPrice;//BeforeDisc
            if SalesLineTmp."Allow Line Disc." then begin
                SalesPriceMgt.FindSalesLineLineDisc(SalesHeaderTmp, SalesLineTmp);
                LineDisc := SalesLineTmp."Line Discount %";
                UnitPrice := UnitPrice * (100 - LineDisc) / 100;
            end;
        end;
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
        //RecRef.GETTABLE(Rec);
        //xRecRef.GETTABLE(xRec);
        //ActionsMgt.SetCalledByTableTrigger(TRUE);
        //ActionsMgt.CreateActionsByRecRef(RecRef,xRecRef,Type);
        //RecRef.CLOSE;
        //xRecRef.CLOSE;

        //Replication is OnPost transaction
    end;
}


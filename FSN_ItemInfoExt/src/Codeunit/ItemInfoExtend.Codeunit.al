codeunit 50005 "FSN Item Info. Extend"
{
    TableNo = 99001586;

    trigger OnRun()
    var
        CodeOffer: Codeunit "FSN Item Info. Extend";
        SubRunCommand: Code[20];
    begin
        SELECTLATESTVERSION;

        IF GlobalCommand = '' THEN
            GlobalCommand := Code;

        InicializeParameters;

        CASE GlobalCommand OF
            'ECOMMERCE_SEND',
            'ECOMMERCE_HIERARCHY',
            'ECOMMERCE_PRICE',
            'ECOM_UPD_ALL':
                BEGIN
                    SubRunCommand := DelChr(GlobalCommand, '=', '_');
                    CodeOffer.SetRUNMode(SubRunCommand);
                    COMMIT;
                    IF CodeOffer.RUN(Rec) THEN;
                END;
            'ECOMMERCESEND':
                CreateItems;
            'ECOMMERCEHIERARCHY':
                UpdateHierarchy;
            'ECOMMERCEPRICE':
                UpdateAllPrices;
            'ECOMUPDALL':
                BEGIN
                    CreateItems;
                    UpdateHierarchy;
                    UpdateAllPrices;
                END;
            'ECOMTEST':
                begin
                    TestingPrice(Rec.Text);
                end;
            /****** HUGO Section *********/
            'UPDHUGOITEM':
                BEGIN
                    CodeOffer.SetRUNMode('HUGO_ITEMRESET');
                    COMMIT;
                    IF CodeOffer.RUN(Rec) THEN;
                    CodeOffer.SetRUNMode('HUGO_ITEM');
                    COMMIT;
                    IF CodeOffer.RUN(Rec) THEN;
                END;
            'UPDHUGOINV':
                BEGIN
                    CodeOffer.SetRUNMode('HUGO_INV');
                    COMMIT;
                    IF CodeOffer.RUN(Rec) THEN;
                END;
            'HUGO_ITEMRESET':
                UpdateHugoReset;
            'HUGO_ITEM':
                UpdateHugoItem;
            'HUGO_INV':
                UpdateInventoryHugoSql;
            /****** Dynamics adaption Section *********/
            'UPDATE_DISC_G':
                UpdateDiscountGroup(Text);

        END;
        CLEAR(GlobalCommand);

    end;

    var
        RequestTxt: Text;
        GlobalHugoPath: Text[250];
        StaticHugoPath: Label 'C:\temp\WSFSN\';
        GlobalCommand: Text[50];
        GlobalParametersSetup: Record "FSN Item Info. Extend" temporary;
        ItemUnitofMeasure: Record "Item Unit of Measure";
        ItemInfoExtend: Record "FSN Item Info. Extend";
        POSPriceUtil: Codeunit "LSC POS Price Utility";
        ItemInfoExt2: Record "FSN Item Info. Extend";
        ItemInfoExtendCopy: Record "FSN Item Info. Extend";
        Store: Record "LSC Store";
        RetailPriceUtil: Codeunit "LSC Retail Price Utils";
        ItemBlockedTmp: Record "FSN Item Info. Extend" temporary;
        BOUtil: Codeunit "LSC BO Utils";
        Item: Record "Item";
        ItemInfoExtTmp: Record "FSN Item Info. Extend" temporary;
        ItemInfoExtPricesTmp: Record "FSN Item Info. Extend" temporary;
        Customer: Record Customer;
        VatSetup: Record "VAT Posting Setup";
        PosFuncProfile: Record "LSC POS Func. Profile";
        RetailSetup: Record "LSC Retail Setup";
        ItemBarcodes: Record "LSC Barcodes";
        ProductGroup: Record "LSC Retail Product Group";
        ItemCategory: Record "Item Category";
        ItemDivision: Record "LSC Division";
        AttributeOptionVal: Record "LSC Attribute Option Value";
        SpecialGroup: Record "LSC Item Special Groups";
        GlobalStore: Code[10];
        GlobalPOS: Code[10];
        GlobalStaff: Code[20];
        GlobalDate: Date;
        GlobalTime: Time;
        GlobalCalcAllProducts: Boolean;
        GlobalExtTxtArr: array[10, 2] of Text;
        Txt2: Label 'Inicialize...';
        Txt3: Label '%1 whitout %2';
        Txt4: Label 'Status: Bloqued on POS';
        Txt5: Label 'Price is %1';
        Txt6: Label 'PROMOS ESPECIALES';
        Txt7: Label 'Cant be delete %1 %2';
        Txt8: Label '%1 %2 %3';
        Txt9: Label 'Inactive';
        Itemli: list of [text];

    #region [internal procedures]
    local procedure GetEcomPrice1FromEcomItem(Rec: Record "FSN Item Info. Extend"; LineDiscGroup: Integer; var RecCopy: Record "FSN Item Info. Extend"; var IsNew: Boolean; NewID: Code[20])
    begin
        //CLEAR(IsNew);
        //CLEAR(NewID);

        IF NOT RecCopy.GET(Rec."Entry Type"::EcommercePrices, Rec."Sub Type"::ItemSetting
          , Rec."No.", Rec."Unit of Measure", LineDiscGroup) THEN BEGIN
            RecCopy.INIT;
            RecCopy."Entry Type" := RecCopy."Entry Type"::EcommercePrices;
            RecCopy."Sub Type" := RecCopy."Sub Type"::ItemSetting;
            RecCopy."No." := Rec."No.";
            RecCopy."Unit of Measure" := Rec."Unit of Measure";
            RecCopy."Source Type" := RecCopy."Source Type"::Automatic;
            RecCopy."Line No." := LineDiscGroup;
            RecCopy.ID := NewID;
            RecCopy.INSERT(TRUE);
            //IsNew := TRUE;
        END;
        IF RecCopy.ID <> NewID THEN BEGIN
            RecCopy.ID := NewID;
            RecCopy.MODIFY(TRUE);
        END;
    end;

    local procedure FillItemInfoExtTmp()
    var
        SpecialGroupLink_l: Record "LSC Item/Special Group Link";
    begin
        ItemInfoExtTmp.RESET;
        ItemInfoExtTmp.DELETEALL;
        CLEAR(ItemInfoExtTmp);

        ItemInfoExtend.RESET;
        ItemInfoExtend.SETRANGE(ItemInfoExtend."Entry Type", ItemInfoExtend."Entry Type"::EcommerceItem);
        ItemInfoExtend.SETRANGE(ItemInfoExtend."Sub Type", ItemInfoExtend."Sub Type"::ItemSetting);
        IF ItemInfoExtend.FIND('-') THEN
            REPEAT
                ItemInfoExtTmp := ItemInfoExtend;
                ItemInfoExtTmp.INSERT;
            UNTIL ItemInfoExtend.NEXT = 0;

        ItemBlockedTmp.RESET;
        ItemBlockedTmp.DELETEALL;
        CLEAR(ItemBlockedTmp);

        ItemInfoExtend.RESET;
        ItemInfoExtend.SETRANGE(ItemInfoExtend."Entry Type", ItemInfoExtend."Entry Type"::EcommerceLimit);
        ItemInfoExtend.SETRANGE(ItemInfoExtend."Sub Type", ItemInfoExtend."Sub Type"::ItemSetting);
        ItemInfoExtend.SETRANGE(ItemInfoExtend."Blocked Ecommerce", TRUE);
        IF ItemInfoExtend.FIND('-') THEN
            REPEAT
                CASE ItemInfoExtend."Item Type" OF
                    ItemInfoExtend."Item Type"::Item:
                        BEGIN
                            IF NOT ItemBlockedTmp.GET(ItemInfoExtend."Entry Type", ItemInfoExtend."Sub Type"::Information, ItemInfoExtend."No.", ItemInfoExtend."Unit of Measure", 0) THEN BEGIN
                                ItemBlockedTmp."Entry Type" := ItemInfoExtend."Entry Type";
                                ItemBlockedTmp."Sub Type" := ItemBlockedTmp."Sub Type"::Information;//Temp
                                ItemBlockedTmp."No." := ItemInfoExtend."No.";
                                ItemBlockedTmp."Unit of Measure" := ItemInfoExtend."Unit of Measure";
                                ItemBlockedTmp."Line No." := 0;
                                ItemBlockedTmp.Reason := COPYSTR(
                                  STRSUBSTNO(Txt8, ItemInfoExtend."Entry Type"::EcommerceLimit, FORMAT(ItemInfoExtend."Item Type"), ItemInfoExtend.FIELDCAPTION("Blocked Ecommerce")), 1, 50);
                                ItemBlockedTmp.INSERT;
                            END;
                        END;
                    ItemInfoExtend."Item Type"::"ProductGroup",
                    ItemInfoExtend."Item Type"::Category,
                    ItemInfoExtend."Item Type"::Division,
                    ItemInfoExtend."Item Type"::"Attribute 1",
                    ItemInfoExtend."Item Type"::"Attribute 2",
                    ItemInfoExtend."Item Type"::"Attribute 3":
                        BEGIN
                            Item.RESET;

                            IF ItemInfoExtend."Item Type" = ItemInfoExtend."Item Type"::ProductGroup THEN
                                Item.SETRANGE(Item."LSC Retail Product Code", ItemInfoExtend."No.")
                            ELSE
                                IF ItemInfoExtend."Item Type" = ItemInfoExtend."Item Type"::Category THEN
                                    Item.SETRANGE(Item."Item Category Code", ItemInfoExtend."No.")
                                ELSE
                                    IF ItemInfoExtend."Item Type" = ItemInfoExtend."Item Type"::Division THEN
                                        Item.SETRANGE(Item."LSC Division Code", ItemInfoExtend."No.")
                                    ELSE
                                        IF ItemInfoExtend."Item Type" = ItemInfoExtend."Item Type"::"Attribute 1" THEN
                                            Item.SETRANGE(Item."LSC Attrib 1 Code", ItemInfoExtend."No.")
                                        ELSE
                                            IF ItemInfoExtend."Item Type" = ItemInfoExtend."Item Type"::"Attribute 2" THEN
                                                Item.SETRANGE(Item."LSC Attrib 2 Code", ItemInfoExtend."No.")
                                            ELSE
                                                IF ItemInfoExtend."Item Type" = ItemInfoExtend."Item Type"::"Attribute 3" THEN
                                                    Item.SETRANGE(Item."LSC Attrib 3 Code", ItemInfoExtend."No.");

                            IF Item.FIND('-') THEN
                                REPEAT
                                    ItemUnitofMeasure.RESET;
                                    ItemUnitofMeasure.SETRANGE(ItemUnitofMeasure."Item No.", Item."No.");
                                    IF ItemUnitofMeasure.FIND('-') THEN
                                        REPEAT
                                            IF NOT ItemBlockedTmp.GET(ItemInfoExtend."Entry Type", ItemInfoExtend."Sub Type"::Information, ItemUnitofMeasure."Item No.", ItemUnitofMeasure.Code, 0) THEN BEGIN
                                                ItemBlockedTmp."Entry Type" := ItemInfoExtend."Entry Type";
                                                ItemBlockedTmp."Sub Type" := ItemBlockedTmp."Sub Type"::Information;
                                                ItemBlockedTmp."No." := ItemUnitofMeasure."Item No.";
                                                ItemBlockedTmp."Unit of Measure" := ItemUnitofMeasure.Code;
                                                ItemBlockedTmp."Line No." := 0;
                                                ItemBlockedTmp.Reason := COPYSTR(
                                                  STRSUBSTNO(Txt8, ItemInfoExtend."Entry Type"::EcommerceLimit, FORMAT(ItemInfoExtend."Item Type"), ItemInfoExtend.FIELDCAPTION("Blocked Ecommerce")), 1, 50);
                                                ItemBlockedTmp.INSERT;
                                            END;
                                        UNTIL ItemUnitofMeasure.NEXT = 0;
                                UNTIL Item.NEXT = 0;
                        END;
                    ItemInfoExtend."Item Type"::ProductGroup:
                        BEGIN
                            SpecialGroupLink_l.RESET;
                            SpecialGroupLink_l.SETRANGE(SpecialGroupLink_l."Special Group Code", ItemInfoExtend."No.");
                            IF SpecialGroupLink_l.FIND('-') THEN
                                REPEAT
                                    ItemUnitofMeasure.RESET;
                                    ItemUnitofMeasure.SETRANGE(ItemUnitofMeasure."Item No.", SpecialGroupLink_l."Item No.");
                                    IF ItemUnitofMeasure.FIND('-') THEN
                                        REPEAT
                                            IF NOT ItemBlockedTmp.GET(ItemInfoExtend."Entry Type", ItemInfoExtend."Sub Type"::Information, ItemUnitofMeasure."Item No.", ItemUnitofMeasure.Code, 0) THEN BEGIN
                                                ItemBlockedTmp."Entry Type" := ItemInfoExtend."Entry Type";
                                                ItemBlockedTmp."Sub Type" := ItemBlockedTmp."Sub Type"::Information;
                                                ItemBlockedTmp."No." := ItemUnitofMeasure."Item No.";
                                                ItemBlockedTmp."Unit of Measure" := ItemUnitofMeasure.Code;
                                                ItemBlockedTmp."Line No." := 0;
                                                ItemBlockedTmp.Reason := COPYSTR(
                                                  STRSUBSTNO(Txt8, ItemInfoExtend."Entry Type"::EcommerceLimit, FORMAT(ItemInfoExtend."Item Type"), ItemInfoExtend.FIELDCAPTION("Blocked Ecommerce")), 1, 50);
                                                ItemBlockedTmp.INSERT;
                                            END;
                                        UNTIL ItemUnitofMeasure.NEXT = 0;
                                UNTIL SpecialGroupLink_l.NEXT = 0;
                        END;
                END;
            UNTIL ItemInfoExtend.NEXT = 0;
    end;

    local procedure FindPeriodicOffers(var currline: Record "LSC POS Trans. Line" temporary; CustomerDiscGroup: Code[20]; var OfferPercent: Decimal; var OfferPrice: Decimal; var BlockTenderOffer: Boolean; SearchTenderOffer: Boolean; var OriginPrice: Decimal; TenderTypeCode: Code[10])
    var
        PeriodicDiscount: Record "LSC Periodic Discount";
        PeriodicDiscountLines: Record "LSC Periodic Discount Line";
        Promotion: Record "LSC Offer";
        found: Boolean;
        tPosTransLine: Record "LSC POS Trans. Line";
        tPerDiscLine: Record "LSC Periodic Discount Line";
        tPerDisc: Record "LSC Periodic Discount";
        ItemSpecialGroup: Record "LSC Item/Special Group Link";
        PerDiscType: Record "LSC POS Trans. Per. Disc. Type"; //"LSC POS Trans. Periodic Disc.";
        InsertOfferOk: Boolean;
        OfferOk: Boolean;
        TotAmount: Decimal;
        DiscItemRecFound: Boolean;
        ItemVariantsFunc: Codeunit "LSC Item Variants Functions";
        AddPosFunctions: Codeunit "LSC Additional POS Commands";
        Exclude: Boolean;
        PeriodicDiscLinesTemp: Record "LSC Periodic Discount Line" temporary;
        TmpPerDiscount: Record "LSC Periodic Discount" temporary;
        TmpPerDiscount2: Record "LSC Periodic Discount" temporary;
        TmpItemPointDiscLine: Record "LSC Periodic Discount Line" temporary;
        CurrUOM: Code[10];
        RecRef: RecordRef;
        FieldRef: FieldRef;
        DateToUse: Date;
        TimeToUse: Time;
        OfferPosCalcTmp: Record "LSC Offer Pos Calculation" temporary;
        RecRefDel: RecordRef;
        PriceGroupCode: Code[20];
    begin
        IF SearchTenderOffer AND BlockTenderOffer THEN BEGIN
            OfferPrice := 0;
            OfferPercent := 0;
            EXIT;
        END;
        TmpPerDiscount2.RESET;
        RecRefDel.GETTABLE(TmpPerDiscount2);
        IF RecRefDel.ISTEMPORARY THEN
            RecRefDel.DELETEALL;

        OfferPosCalcTmp.RESET;
        RecRefDel.GETTABLE(OfferPosCalcTmp);
        IF RecRefDel.ISTEMPORARY THEN
            RecRefDel.DELETEALL;

        CLEAR(OfferPrice);
        CLEAR(OfferPercent);
        CLEAR(BlockTenderOffer);
        CLEAR(OriginPrice);

        RecRef.GETTABLE(PeriodicDiscount);
        RecRef.CURRENTKEYINDEX(2);
        FieldRef := RecRef.FIELD(3);
        FieldRef.SETRANGE(TmpPerDiscount.Status::Enabled);
        FieldRef := RecRef.FIELD(4);
        IF SearchTenderOffer THEN
            FieldRef.SETRANGE(TmpPerDiscount.Type::"Tender Type")
        ELSE
            FieldRef.SETRANGE(TmpPerDiscount.Type::Multibuy, TmpPerDiscount.Type::"Disc. Offer");
        FieldRef := RecRef.FIELD(25);
        FieldRef.SETFILTER('%1|%2', Store."Currency Code", '');

        PeriodicDiscountLines.SETCURRENTKEY("Offer No.", Type, "No.", "Variant Code", "Unit of Measure", "Prod. Group Category");
        IF currline."Unit of Measure" <> '' THEN
            CurrUOM := currline."Unit of Measure"
        ELSE
            CurrUOM := Item."Sales Unit of Measure";
        PeriodicDiscountLines.SETFILTER("Unit of Measure", '%1|%2', CurrUOM, '');

        IF RecRef.FIND('-') THEN
            REPEAT
                RecRef.SETTABLE(TmpPerDiscount);

                DateToUse := GlobalDate;
                TimeToUse := GlobalTime;
                PriceGroupCode := TmpPerDiscount."Price Group";
                IF PriceGroupCode = 'ALL' THEN
                    PriceGroupCode := '';


                IF ((TmpPerDiscount."Customer Disc. Group" = '') OR
                    (TmpPerDiscount."Customer Disc. Group" = CustomerDiscGroup)) AND
                   //RetailPriceUtil.CouponFilterPassed(TmpPerDiscount."Coupon Code",TmpPerDiscount."Coupon Qty Needed") AND
                   //RetailPriceUtil.MemberFilterPassed(TmpPerDiscount."Member Type",TmpPerDiscount."Member Value") AND
                   //RetailPriceUtil.MemberAttrFilterPassed(TmpPerDiscount."Member Attribute",TmpPerDiscount."Member Attribute Value") AND
                   //RetailPriceUtil.MemberLimitationFilterPassed(TmpPerDiscount."Discount Tracking No.") AND
                   (TmpPerDiscount."Coupon Code" = '') AND                                 //Extra-
                   (TmpPerDiscount."Member Value" = '') AND
                   (TmpPerDiscount."Member Attribute" = '') AND
                   (TmpPerDiscount."Member Attribute Value" = '') AND
                   (TmpPerDiscount."Amount to Trigger" = 0) AND
                   (TmpPerDiscount.Type <> TmpPerDiscount.Type::"Mix&Match") AND
                   ((NOT SearchTenderOffer) OR (TmpPerDiscount."Tender Type Code" = TenderTypeCode)) AND
                    BOUtil.PriceGroupValidInStore2(PriceGroupCode, currline."Store No.") AND  //Filter sale
                    (TmpPerDiscount."Sales Type Filter" = '') //Extra
                THEN BEGIN
                    found := FALSE;
                    Exclude := FALSE;
                    PeriodicDiscountLines.SETRANGE(PeriodicDiscountLines."Offer No.", TmpPerDiscount."No.");
                    DiscItemRecFound := FALSE;
                    PeriodicDiscountLines.SETRANGE(Type, PeriodicDiscountLines.Type::Item);
                    PeriodicDiscountLines.SETRANGE("No.", Item."No.");
                    IF currline."Variant Code" <> '' THEN BEGIN
                        PeriodicDiscountLines.SETRANGE("Variant Type", PeriodicDiscountLines."Variant Type"::Variant);
                        PeriodicDiscountLines.SETRANGE("Variant Code", currline."Variant Code");
                        IF PeriodicDiscountLines.FIND('+') THEN
                            DiscItemRecFound := TRUE;
                        IF NOT DiscItemRecFound THEN BEGIN
                            PeriodicDiscountLines.SETRANGE("Variant Type", PeriodicDiscountLines."Variant Type"::"Dimension 1");
                            PeriodicDiscountLines.SETRANGE("Variant Code", ItemVariantsFunc.GetVariantDim1Value(Item."No.", currline."Variant Code"));
                            IF PeriodicDiscountLines.FIND('+') THEN
                                DiscItemRecFound := TRUE;
                        END;
                        IF NOT DiscItemRecFound THEN BEGIN
                            PeriodicDiscountLines.SETRANGE("Variant Type");
                            PeriodicDiscountLines.SETRANGE("Variant Code", '');
                            IF PeriodicDiscountLines.FIND('+') THEN
                                DiscItemRecFound := TRUE;
                        END;
                    END ELSE BEGIN
                        PeriodicDiscountLines.SETRANGE("Variant Type");
                        PeriodicDiscountLines.SETRANGE("Variant Code", '');
                        IF PeriodicDiscountLines.FIND('+') THEN
                            DiscItemRecFound := TRUE;
                    END;
                    IF DiscItemRecFound THEN BEGIN
                        IF RetailPriceUtil.PeriodDiscFiltersPassed(
                             TmpPerDiscount, currline."Store No.", currline."Sales Type", currline."Price Group Code") AND
                           RetailPriceUtil.DiscValPerValid(TmpPerDiscount."Validation Period ID", DateToUse, TimeToUse) //LS7.1-02
                        THEN BEGIN
                            found := TRUE;
                            Exclude := PeriodicDiscountLines.Exclude;
                        END;

                        found := TRUE;
                        Exclude := PeriodicDiscountLines.Exclude;
                    END;

                    IF NOT found THEN BEGIN
                        CLEAR(ItemSpecialGroup);
                        ItemSpecialGroup.SETRANGE(ItemSpecialGroup."Item No.", Item."No.");
                        IF ItemSpecialGroup.FINDSET THEN BEGIN
                            PeriodicDiscLinesTemp.RESET;
                            PeriodicDiscLinesTemp.DELETEALL;
                            REPEAT
                                PeriodicDiscountLines.SETRANGE(Type, PeriodicDiscountLines.Type::"Special Group");
                                PeriodicDiscountLines.SETRANGE("No.", ItemSpecialGroup."Special Group Code");
                                IF PeriodicDiscountLines.FINDFIRST THEN BEGIN
                                    IF RetailPriceUtil.PeriodDiscFiltersPassed(
                                       TmpPerDiscount, currline."Store No.", currline."Sales Type", currline."Price Group Code") AND
                                     RetailPriceUtil.DiscValPerValid(
                                       TmpPerDiscount."Validation Period ID", DateToUse, TimeToUse) //LS7.1-02
                                    THEN BEGIN
                                        found := TRUE;
                                        Exclude := PeriodicDiscountLines.Exclude;
                                        PeriodicDiscLinesTemp.INIT;
                                        PeriodicDiscLinesTemp := PeriodicDiscountLines;
                                        PeriodicDiscLinesTemp.INSERT;
                                    END;
                                END;
                            UNTIL (ItemSpecialGroup.NEXT = 0) OR Exclude;
                            IF (found) AND (NOT Exclude) THEN
                                POSPriceUtil.FindBestSpecialGrDiscLine(currline, PeriodicDiscLinesTemp, PeriodicDiscountLines);
                        END;
                    END;

                    IF NOT found THEN BEGIN
                        PeriodicDiscountLines.SETRANGE(Type, PeriodicDiscountLines.Type::"Product Group");
                        PeriodicDiscountLines.SETRANGE("No.", Item."LSC Retail Product Code");
                        PeriodicDiscountLines.SETRANGE("Prod. Group Category", Item."Item Category Code");
                        IF PeriodicDiscountLines.FIND('-') THEN BEGIN
                            IF RetailPriceUtil.PeriodDiscFiltersPassed(
                                 TmpPerDiscount, currline."Store No.", currline."Sales Type", currline."Price Group Code") AND
                               RetailPriceUtil.DiscValPerValid(
                                 TmpPerDiscount."Validation Period ID", DateToUse, TimeToUse) //LS7.1-02
                            THEN BEGIN
                                found := TRUE;
                                Exclude := PeriodicDiscountLines.Exclude;
                            END;
                        END;
                        PeriodicDiscountLines.SETRANGE("Prod. Group Category");
                    END;

                    IF NOT found THEN BEGIN
                        PeriodicDiscountLines.SETRANGE(Type, PeriodicDiscountLines.Type::"Item Category");
                        PeriodicDiscountLines.SETRANGE("No.", Item."Item Category Code");
                        IF PeriodicDiscountLines.FIND('-') THEN BEGIN
                            IF RetailPriceUtil.PeriodDiscFiltersPassed(
                                 TmpPerDiscount, currline."Store No.", currline."Sales Type", currline."Price Group Code") AND
                               RetailPriceUtil.DiscValPerValid(
                                 TmpPerDiscount."Validation Period ID", DateToUse, TimeToUse) //LS7.1-02
                            THEN BEGIN
                                found := TRUE;
                                Exclude := PeriodicDiscountLines.Exclude;
                            END;
                        END;
                    END;

                    IF (NOT found) AND (TmpPerDiscount.Type = TmpPerDiscount.Type::"Disc. Offer") THEN BEGIN
                        PeriodicDiscountLines.SETRANGE(Type, PeriodicDiscountLines.Type::All);
                        PeriodicDiscountLines.SETRANGE("No.");
                        IF PeriodicDiscountLines.FIND('-') THEN BEGIN
                            IF RetailPriceUtil.PeriodDiscFiltersPassed(
                                 TmpPerDiscount, currline."Store No.", currline."Sales Type", currline."Price Group Code") AND
                               RetailPriceUtil.DiscValPerValid(
                                 TmpPerDiscount."Validation Period ID", DateToUse, TimeToUse) //LS7.1-02
                            THEN BEGIN
                                found := TRUE;
                                Exclude := PeriodicDiscountLines.Exclude;
                            END;
                        END;
                    END;
                    /*
                    IF (NOT found) AND (TmpPerDiscount.Type <> TmpPerDiscount.Type::Multibuy) AND
                      (TmpPerDiscount."Amount to Trigger" <> 0)
                    THEN BEGIN
                      PosTrans.CALCFIELDS("Gross Amount","Line Discount","Income/Exp. Amount");
                      TotAmount := PosTrans."Gross Amount" + PosTrans."Line Discount" + PosTrans."Income/Exp. Amount";
                      IF (TotAmount >= TmpPerDiscount."Amount to Trigger") OR
                         (PosTransOfferCount(currline."Receipt No.",0,TmpPerDiscount."No.") > 0)
                      THEN BEGIN
                        InsertTmpOffer(TmpPerDiscount."No.");
                      END;
                    END;
                    *///Not used in BC

                    IF (found) AND (NOT Exclude) AND
                      RetailPriceUtil.DiscValPerValid(
                        TmpPerDiscount."Validation Period ID", DateToUse, TimeToUse) THEN BEGIN

                        TmpPerDiscount2 := TmpPerDiscount;
                        IF TmpPerDiscount2.INSERT THEN;

                        OfferPosCalcTmp.INIT;
                        OfferPosCalcTmp."Receipt No." := currline."Receipt No.";
                        OfferPosCalcTmp."Periodic Disc. Type" := TmpPerDiscount.Type;
                        OfferPosCalcTmp."Group No." := PeriodicDiscountLines."Offer No.";
                        OfferPosCalcTmp."Trans. Line No." := currline."Line No.";
                        OfferPosCalcTmp."Offer Line No." := PeriodicDiscountLines."Line No.";
                        OfferPosCalcTmp."Use Trans. Line Time" := TmpPerDiscount."Use Trans. Line Time";
                        IF NOT OfferPosCalcTmp.INSERT THEN
                            OfferPosCalcTmp.MODIFY;

                        found := FALSE;
                    END;
                END;
            UNTIL RecRef.NEXT = 0;

        TmpPerDiscount2.SETCURRENTKEY(Priority);
        IF TmpPerDiscount2.FIND('-') THEN BEGIN
            OfferPosCalcTmp.SETCURRENTKEY("Receipt No.", "Periodic Disc. Type", "Group No.", "Trans. Line No.");
            OfferPosCalcTmp.SETRANGE(OfferPosCalcTmp."Receipt No.", currline."Receipt No.");
            OfferPosCalcTmp.SETRANGE(OfferPosCalcTmp."Trans. Line No.", currline."Line No.");
            OfferPosCalcTmp.SETRANGE(OfferPosCalcTmp."Group No.", TmpPerDiscount2."No.");
            IF OfferPosCalcTmp.FIND('-') THEN BEGIN
                IF NOT SearchTenderOffer THEN
                    IF tPerDiscLine.GET(OfferPosCalcTmp."Group No.", OfferPosCalcTmp."Offer Line No.") THEN BEGIN
                        OfferPercent := tPerDiscLine."Deal Price/Disc. %";
                        OfferPrice := tPerDiscLine."Offer Price Including VAT";
                        BlockTenderOffer := TmpPerDiscount2."Block Tender Type Discount";
                        OriginPrice := PeriodicDiscountLines."Standard Price Including VAT";
                    END;

                IF SearchTenderOffer THEN BEGIN
                    OfferPosCalcTmp.RESET;
                    IF OfferPosCalcTmp.FIND('-') THEN
                        REPEAT
                            IF TmpPerDiscount2.GET(OfferPosCalcTmp."Group No.") AND (TmpPerDiscount2."Tender Offer %" <> 0) THEN
                                OfferPercent += TmpPerDiscount2."Tender Offer %"
                            ELSE
                                IF tPerDiscLine.GET(OfferPosCalcTmp."Group No.", OfferPosCalcTmp."Offer Line No.") THEN BEGIN
                                    OfferPercent := tPerDiscLine."Deal Price/Disc. %";
                                END;
                        UNTIL OfferPosCalcTmp.NEXT = 0;
                END;
            END;
        END;

    end;

    local procedure UpdateDiscountGroup(DGroup: Text)
    var
        DiscountGroup: Record "Customer Discount Group";
        IteminfoExt: Record "FSN Item Info. Extend";
        _ItemInfoExt: Record "FSN Item Info. Extend";
        LastLineNo: Integer;
        IsNew: Boolean;
    begin
        if not Discountgroup.Get(DGroup) then
            exit;

        Clear(IsNew);
        Clear(ItemInfoExtTmp);

        _ItemInfoExt.Reset();
        _ItemInfoExt.SetRange(ID, DGroup);
        if not _ItemInfoExt.Find('-') then
            IsNew := true;

        if IsNew then begin
            _ItemInfoExt.Reset();
            _ItemInfoExt.SetCurrentKey("Entry Type", "Sub Type", "No.", "Unit of Measure", "Line No.");
            _ItemInfoExt.SetRange("Entry Type", _ItemInfoExt."Entry Type"::EcommercePrices);
            _ItemInfoExt.SetRange("Sub Type", _ItemInfoExt."Sub Type"::ItemSetting);
            if _ItemInfoExt.FindLast then
                LastLineNo := _ItemInfoExt."Line No." + 100;
        end;

        ItemInfoExt.Reset();
        ItemInfoExt.SetCurrentKey("Entry Type", "Sub Type", "No.", "Unit of Measure", "Line No.");
        ItemInfoExt.SetRange("Entry Type", _ItemInfoExt."Entry Type"::EcommerceItem);
        ItemInfoExt.SetRange("Sub Type", _ItemInfoExt."Sub Type"::ItemSetting);
        ItemInfoExt.SetRange(ID, 'RETAIL');
        if IteminfoExt.Find('-') then
            repeat
                GetEcomPrice1FromEcomItem(ItemInfoExt, LastLineNo, ItemInfoExtTmp, IsNew, DGroup);
                CalcOffercLine(ItemInfoExtTmp, DGroup, GetIDParameter('EMPRERETAIL', '20'));
                UpdateChanges(ItemInfoExtTmp);
                ItemInfoExtTmp.Modify(false);
            until IteminfoExt.Next() = 0;

        ItemInfoExtTmp.Find('-');
        _ItemInfoExt.Reset();
        repeat
            _ItemInfoExt.Init();
            _ItemInfoExt.TransferFields(ItemInfoExtTmp);

            if not IsNew then begin
                ItemInfoExt.Reset();
                ItemInfoExt.SetCurrentKey("Entry Type", "Sub Type", "No.", "Unit of Measure", "Line No.");
                ItemInfoExt.SetRange("Entry Type", ItemInfoExtTmp."Entry Type");
                ItemInfoExt.SetRange("Sub Type", ItemInfoExtTmp."Sub Type");
                ItemInfoExt.SetRange("No.", ItemInfoExtTmp."No.");
                ItemInfoExt.SetRange(ID, ItemInfoExtTmp.ID);
                if ItemInfoExt.FindFirst() then begin
                    if RecordTmpChanged(ItemInfoExtTmp, ItemInfoExt) then
                        ItemInfoExtTmp.Modify(true);
                end else
                    ItemInfoExtTmp.Insert(true);
            end else
                ItemInfoExtTmp.Insert(true);

        until ItemInfoExtTmp.Next() = 0;
    end;

    local procedure VerifyBlockedItem(ItemCode: Text; UOMCode: Text): Boolean
    var
        barcodes: Record "LSC Barcodes";
        POSSession: Codeunit "LSC POS Session";
    begin
        barcodes.Reset();
        barcodes.SetRange("Item No.", ItemCode);
        barcodes.Setrange("Unit of Measure Code", UOMCode);
        if barcodes.FindFirst() then
            POSSession.SetValue('FSN_Barcode', barcodes."Barcode No.");
        exit(barcodes."FSN Blocked");
    end;


    #endregion
    #region [External procedures]
    procedure InicializeParameters(): Boolean
    var
        RetailUser_l: Record "LSC Retail User";
    begin
        IF GlobalStore <> '' THEN//Alredy read setup
            EXIT(TRUE);
        GlobalParametersSetup.RESET;
        GlobalParametersSetup.DELETEALL;
        CLEAR(GlobalParametersSetup);
        ItemInfoExtend.RESET;
        ItemInfoExtend.SETRANGE(ItemInfoExtend."Entry Type", ItemInfoExtend."Entry Type"::Parameters);
        ItemInfoExtend.SETRANGE(ItemInfoExtend."Sub Type", ItemInfoExtend."Sub Type"::ItemSetting);
        IF ItemInfoExtend.FIND('-') THEN
            REPEAT
                GlobalParametersSetup := ItemInfoExtend;
                GlobalParametersSetup.INSERT;
            UNTIL ItemInfoExtend.NEXT = 0;

        IF RetailUser_l.GET(GetIDParameter('FASANI\WS', 'FASANI\WS')) THEN BEGIN
            GlobalStore := RetailUser_l."Store No.";
            GlobalPOS := RetailUser_l."POS Terminal";
            GlobalDate := TODAY;
            GlobalTime := TIME;
            GlobalStaff := GetIDParameter('ESTAFF', '');
            GlobalCalcAllProducts := TRUE;
        END;

        EXIT(GlobalStore <> '');
    end;

    procedure ValidateRecordType(var Rec: Record "FSN Item Info. Extend")
    var
        PeriodicDiscount_l: Record "LSC Periodic Discount";
        AttributeSetup_l: Record "LSC Attribute Setup";
        Txt1: Label 'Offer: %1';
    begin
        RetailSetup.GET;
        AttributeSetup_l.Get();
        WITH Rec DO BEGIN

            IF "Entry Type" = Rec."Entry Type"::ItemInformation THEN
                IF Item.GET("No.") THEN
                    Rec.Description := Item.Description;


            IF ("Entry Type" IN ["Entry Type"::EcommerceLimit,
                                "Entry Type"::EcommerceItem,
                                "Entry Type"::EcommercePrices,
                                "Entry Type"::EcommerceHierarchy]) AND ("Source Type" <> "Source Type"::CopyTemporary)
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
                                Description := ItemBarcodes.Description;

                            IF Item.GET("No.") THEN BEGIN
                                IF Description = '' THEN
                                    Description := Item.Description;
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
                                ProductGroup.SETFILTER(Code, "No.");
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

    procedure SetRUNMode(pCommand: Text[50])
    begin
        ClearGlobals();
        GlobalCommand := pCommand;
    end;

    procedure ClearGlobals()
    begin
        CLEAR(GlobalCommand);
        CLEAR(GlobalStore);
        CLEAR(GlobalPOS);
        CLEAR(GlobalStaff);
        CLEAR(GlobalDate);
        CLEAR(GlobalTime);
        CLEAR(GlobalCalcAllProducts);
    end;

    procedure ClearRecordExpire(pDate: Date)
    begin
        ItemInfoExtend.RESET;
        ItemInfoExtend.SETFILTER(ItemInfoExtend."Entry Type", '3..5');
        ItemInfoExtend.SETFILTER(ItemInfoExtend."Line No.", '>0');
        IF ItemInfoExtend.FIND('-') THEN
            REPEAT
                IF ValidateExpireDT(ItemInfoExtend) THEN
                    ItemInfoExtend.DELETE(TRUE);

            UNTIL ItemInfoExtend.NEXT = 0;
    end;

    procedure CheckOnDelete(Rec: Record "FSN Item Info. Extend")
    begin
        IF Rec."Entry Type" <> Rec."Entry Type"::EcommerceLimit THEN
            IF Rec."Source Type" = Rec."Source Type"::AutomaticStatic THEN
                ERROR(STRSUBSTNO(Txt7, Rec.FIELDCAPTION("Source Type"), FORMAT(Rec."Source Type"::AutomaticStatic)));
        IF Rec."Entry Type" = Rec."Entry Type"::EcommerceItem THEN BEGIN
            ItemInfoExt2.RESET;
            ItemInfoExt2.SETRANGE(ItemInfoExt2."Entry Type", ItemInfoExt2."Entry Type"::EcommercePrices);
            ItemInfoExt2.SETRANGE(ItemInfoExt2."Sub Type", ItemInfoExt2."Sub Type"::ItemSetting);
            ItemInfoExt2.SETRANGE(ItemInfoExt2."Unit of Measure", Rec."Unit of Measure");
            ItemInfoExt2.SETRANGE(ItemInfoExt2."No.", Rec."No.");
            ItemInfoExt2.DELETEALL(TRUE);
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

    procedure UpdateAllPrices()
    var
        TableCaptionBlock: Text[50];
        BlockFromHierarchy: Boolean;
        SetupHierarchy: Record "FSN Item Info. Extend";
        HierarchyActiveTMP: Record "FSN Item Info. Extend" temporary;
        Expired: Boolean;
        OkDateTime: Boolean;
        i: Integer;
        ParentActive: Boolean;
        TenderCode: Code[20];
        IsNew: Boolean;
        UMExists: Boolean;
        ItemPriceTmp: array[2] of Record "FSN Item Info. Extend" temporary;
    begin
        UpdateDTCommand(TRUE);
        COMMIT;

        IF NOT InicializeParameters THEN
            EXIT;

        IF NOT Customer.GET(GetIDParameter('ECUST', '')) THEN BEGIN
            Customer.RESET;
            Customer.SETRANGE(Customer."Customer Disc. Group", 'RETAIL');
            IF NOT Customer.FINDFIRST THEN BEGIN
                Customer.RESET;
                Customer.FINDFIRST;
            END;
        END;

        ClearRecordExpire(GlobalDate);

        HierarchyActiveTMP.RESET;
        HierarchyActiveTMP.DELETEALL;

        FOR i := 3 DOWNTO 1 DO BEGIN
            SetupHierarchy.RESET;
            SetupHierarchy.SETRANGE(SetupHierarchy."Entry Type", SetupHierarchy."Entry Type"::EcommerceHierarchy);
            SetupHierarchy.SETRANGE(SetupHierarchy."Sub Type", SetupHierarchy."Sub Type"::ItemSetting);
            SetupHierarchy.SETRANGE(SetupHierarchy."Item Type", i); //Item type
            SetupHierarchy.SETFILTER(SetupHierarchy."Line No.", '>0');
            IF SetupHierarchy.FIND('-') THEN
                REPEAT
                    CLEAR(ParentActive);
                    IF i = 3 THEN
                        ParentActive := NOT SetupHierarchy."Blocked Ecommerce"
                    ELSE BEGIN
                        ParentActive := HierarchyActiveTMP.GET(SetupHierarchy."Entry Type", SetupHierarchy."Sub Type"
                            , SetupHierarchy."Hierarchy Parent Code", SetupHierarchy."Unit of Measure", 0) AND NOT HierarchyActiveTMP."Blocked Ecommerce";
                    END;
                    IF ParentActive THEN
                        IF ValidateDateTimeRecord(SetupHierarchy) THEN
                            IF NOT HierarchyActiveTMP.GET(SetupHierarchy."Entry Type", SetupHierarchy."Sub Type"
                              , SetupHierarchy."No.", SetupHierarchy."Unit of Measure", 0) THEN BEGIN
                                HierarchyActiveTMP := SetupHierarchy;
                                HierarchyActiveTMP."Line No." := 0;
                                HierarchyActiveTMP.INSERT;
                            END;
                UNTIL SetupHierarchy.NEXT = 0;
            SetupHierarchy.SETRANGE(SetupHierarchy."Line No.", 0);
            IF SetupHierarchy.FIND('-') THEN
                REPEAT
                    CLEAR(ParentActive);
                    IF i = 3 THEN
                        ParentActive := NOT SetupHierarchy."Blocked Ecommerce"
                    ELSE BEGIN
                        ParentActive := HierarchyActiveTMP.GET(SetupHierarchy."Entry Type", SetupHierarchy."Sub Type"
                            , SetupHierarchy."Hierarchy Parent Code", SetupHierarchy."Unit of Measure", 0) AND NOT HierarchyActiveTMP."Blocked Ecommerce";
                    END;
                    IF ParentActive THEN
                        IF ValidateDateTimeRecord(SetupHierarchy) THEN
                            IF NOT HierarchyActiveTMP.GET(SetupHierarchy."Entry Type", SetupHierarchy."Sub Type"
                              , SetupHierarchy."No.", SetupHierarchy."Unit of Measure", 0) THEN BEGIN
                                HierarchyActiveTMP := SetupHierarchy;
                                HierarchyActiveTMP."Line No." := 0;
                                HierarchyActiveTMP.INSERT;
                            END;
                UNTIL SetupHierarchy.NEXT = 0;
        END;

        FillItemInfoExtTmp;
        ItemInfoExtPricesTmp.RESET;
        ItemInfoExtPricesTmp.DELETEALL;
        CLEAR(ItemInfoExtPricesTmp);
        ItemPriceTmp[1].RESET;
        ItemPriceTmp[1].DELETEALL;
        ItemPriceTmp[2].RESET;
        ItemPriceTmp[2].DELETEALL;
        CLEAR(ItemPriceTmp[1]);
        CLEAR(ItemPriceTmp[2]);

        RetailSetup.GET;
        ItemInfoExtTmp.RESET;
        ItemInfoExtTmp.SETRANGE(ItemInfoExtTmp."Line No.", 0);
        IF ItemInfoExtTmp.FIND('-') THEN
            REPEAT
                CLEAR(TableCaptionBlock);
                CLEAR(BlockFromHierarchy);

                Expired := ValidateExpireDT(ItemInfoExtTmp);

                IF NOT HierarchyActiveTMP.GET(HierarchyActiveTMP."Entry Type"::EcommerceHierarchy
                                        , HierarchyActiveTMP."Sub Type"::ItemSetting
                                        , ItemInfoExtTmp."Hierarchy Parent Code", '', 0) THEN BEGIN
                    BlockFromHierarchy := TRUE;
                    TableCaptionBlock := COPYSTR(STRSUBSTNO(Txt8, ItemInfoExtTmp.FIELDCAPTION("Hierarchy Parent Code"), Txt9, ''), 1, 50);
                END;

                IF NOT BlockFromHierarchy THEN
                    IF ItemBlockedTmp.GET(ItemBlockedTmp."Entry Type"::EcommerceLimit, ItemBlockedTmp."Sub Type"::Information, ItemInfoExtTmp."No.", ItemInfoExtTmp."Unit of Measure", 0) THEN BEGIN
                        BlockFromHierarchy := TRUE;
                        TableCaptionBlock := ItemBlockedTmp.Reason;
                    END;

                UMExists := TRUE;
                IF NOT ItemUnitofMeasure.GET(ItemInfoExtTmp."No.", ItemInfoExtTmp."Unit of Measure") THEN BEGIN
                    BlockFromHierarchy := TRUE;
                    TableCaptionBlock := STRSUBSTNO(Txt3, '', ItemUnitofMeasure.TABLECAPTION);
                    UMExists := FALSE;
                END;

                IF (BlockFromHierarchy) THEN BEGIN
                    IF NOT ItemInfoExtTmp."Blocked Ecommerce" THEN BEGIN
                        ItemInfoExtTmp.VALIDATE("Starting Date", 0D);
                        ItemInfoExtTmp.VALIDATE("Ending Date", 0D);
                        ItemInfoExtTmp.Reason := TableCaptionBlock;
                        ItemInfoExtTmp."Blocked Ecommerce" := TRUE;
                        ItemInfoExtTmp.MODIFY;
                    END ELSE
                        IF ItemInfoExtTmp.Reason <> TableCaptionBlock THEN BEGIN
                            ItemInfoExtTmp.Reason := TableCaptionBlock;
                            ItemInfoExtTmp.MODIFY;
                        END;
                END ELSE BEGIN
                    IF Expired THEN BEGIN
                        ItemInfoExtTmp.VALIDATE("Starting Date", 0D);
                        ItemInfoExtTmp.VALIDATE("Ending Date", 0D);
                        ItemInfoExtTmp.MODIFY;
                    END;

                    OkDateTime := ValidateDateTimeRecord(ItemInfoExtTmp);
                    IF OkDateTime THEN BEGIN
                        UpdateChanges(ItemInfoExtTmp);
                        ItemInfoExtTmp.MODIFY;
                    END;
                END;

                //Disc
                IF UMExists THEN BEGIN
                    IF Item."No." <> ItemInfoExtTmp."No." THEN
                        IF Item.GET(ItemInfoExtTmp."No.") THEN;
                    IF Customer."VAT Bus. Posting Group" = '' THEN
                        Customer."VAT Bus. Posting Group" := Store."Store VAT Bus. Post. Gr.";
                    IF NOT VatSetup.GET(Customer."VAT Bus. Posting Group", Item."VAT Prod. Posting Group") THEN
                        VatSetup.INIT;

                    TenderCode := GetIDParameter('EMPRETAIL', '20');
                    CalcOffercLine(ItemInfoExtTmp, 'RETAIL', TenderCode);
                    ItemInfoExtTmp.MODIFY;

                    TenderCode := GetIDParameter('EMPVIP', '20');
                    GetEcomPrice1FromEcomItem(ItemInfoExtTmp, 0, ItemInfoExtendCopy, IsNew, 'VIP');
                    ItemPriceTmp[2] := ItemInfoExtendCopy;
                    ItemPriceTmp[2].INSERT;
                    CalcOffercLine(ItemPriceTmp[2], 'VIP', TenderCode);
                    ItemPriceTmp[2].MODIFY;

                    TenderCode := GetIDParameter('EMPBAVIP', '5');//Temp
                    GetEcomPrice1FromEcomItem(ItemInfoExtTmp, 200, ItemInfoExtendCopy, IsNew, 'VIP_BA');//Static Line
                    ItemPriceTmp[1] := ItemInfoExtendCopy;
                    ItemPriceTmp[1].INSERT;
                    CalcOffercLine(ItemPriceTmp[1], 'VIP', TenderCode);
                    ItemPriceTmp[1].MODIFY;

                    IF ItemInfoExtTmp.Description = '' THEN BEGIN
                        ItemInfoExtTmp.Description := Item.Description;
                        ItemInfoExtTmp.MODIFY;
                    END;
                    IF ItemPriceTmp[1].Description = '' THEN BEGIN
                        ItemPriceTmp[1].Description := ItemInfoExtTmp.Description;
                        ItemPriceTmp[1].MODIFY;
                    END;
                    IF ItemPriceTmp[2].Description = '' THEN BEGIN
                        ItemPriceTmp[2].Description := ItemInfoExtTmp.Description;
                        ItemPriceTmp[2].MODIFY;
                    END;
                END;
                //Disc
                IF UMExists THEN
                    IF BlockFromHierarchy AND NOT ItemInfoExtTmp."Blocked Ecommerce" THEN BEGIN
                        ItemInfoExtTmp."Blocked Ecommerce" := TRUE;
                        ItemInfoExtTmp.Reason := TableCaptionBlock;
                        ItemInfoExtTmp.MODIFY;
                    END;
                IF UMExists THEN BEGIN
                    IF ItemPriceTmp[1]."Blocked Ecommerce" <> ItemInfoExtTmp."Blocked Ecommerce" THEN BEGIN
                        ItemPriceTmp[1]."Blocked Ecommerce" := ItemInfoExtTmp."Blocked Ecommerce";
                        ItemPriceTmp[1].Reason := ItemInfoExtTmp.Reason;
                        ItemPriceTmp[1].MODIFY;
                    END;
                    IF ItemPriceTmp[2]."Blocked Ecommerce" <> ItemInfoExtTmp."Blocked Ecommerce" THEN BEGIN
                        ItemPriceTmp[2]."Blocked Ecommerce" := ItemInfoExtTmp."Blocked Ecommerce";
                        ItemPriceTmp[2].Reason := ItemInfoExtTmp.Reason;
                        ItemPriceTmp[2].MODIFY;
                    END;
                END;
            UNTIL ItemInfoExtTmp.NEXT = 0;

        ItemInfoExtTmp.RESET;
        ItemInfoExtTmp.SETRANGE(ItemInfoExtTmp."Line No.", 0);
        IF ItemInfoExtTmp.FIND('-') THEN
            REPEAT

                IF ItemInfoExtend.GET(ItemInfoExtTmp."Entry Type", ItemInfoExtTmp."Sub Type", ItemInfoExtTmp."No."
                  , ItemInfoExtTmp."Unit of Measure", ItemInfoExtTmp."Line No.") THEN BEGIN
                    IF RecordTmpChanged(ItemInfoExtTmp, ItemInfoExtend) THEN BEGIN
                        ItemInfoExtTmp."Image Link" := ItemInfoExtend."Image Link"; //WVILLALTA 04.21
                        ItemInfoExtend.TRANSFERFIELDS(ItemInfoExtTmp);
                        ItemInfoExtend.MODIFY(TRUE);
                    END;
                    ItemInfoExt2.SETRANGE(ItemInfoExt2."Entry Type", ItemInfoExtend."Entry Type");
                    ItemInfoExt2.SETRANGE(ItemInfoExt2."Sub Type", ItemInfoExtend."Sub Type");
                    ItemInfoExt2.SETRANGE(ItemInfoExt2."No.", ItemInfoExtend."No.");
                    ItemInfoExt2.SETRANGE(ItemInfoExt2."Unit of Measure", ItemInfoExtend."Unit of Measure");
                    ItemInfoExt2.SETRANGE(ItemInfoExt2."Line No.", ItemInfoExtend."Line No." + 1, ItemInfoExtend."Line No." + 3);
                    IF ItemInfoExt2.FIND('-') THEN
                        REPEAT
                            IF ItemInfoExt2."Price Default" <> ItemInfoExtend."Price Default" THEN BEGIN
                                ItemInfoExt2."Price Default" := ItemInfoExtend."Price Default";
                                ItemInfoExt2."Price Inc. Disc. Default" := ItemInfoExtend."Price Default" - ROUND((ItemInfoExt2."Discount Default" / 100) * ItemInfoExtend."Price Default", 0.01);
                                ItemInfoExt2.MODIFY(TRUE);
                            END;
                        UNTIL ItemInfoExt2.NEXT = 0;
                END;
            UNTIL ItemInfoExtTmp.NEXT = 0;

        ItemPriceTmp[2].RESET;
        ItemPriceTmp[2].SETRANGE(ItemPriceTmp[2]."Line No.", 0);
        IF ItemPriceTmp[2].FIND('-') THEN
            REPEAT
                IF ItemInfoExtend.GET(ItemPriceTmp[2]."Entry Type", ItemPriceTmp[2]."Sub Type", ItemPriceTmp[2]."No."
                  , ItemPriceTmp[2]."Unit of Measure", ItemPriceTmp[2]."Line No.") THEN BEGIN
                    IF RecordTmpChanged(ItemPriceTmp[2], ItemInfoExtend) THEN BEGIN
                        ItemInfoExtend.TRANSFERFIELDS(ItemPriceTmp[2]);
                        ItemInfoExtend.MODIFY(TRUE);
                    END;
                    ItemInfoExt2.SETRANGE(ItemInfoExt2."Entry Type", ItemInfoExtend."Entry Type");
                    ItemInfoExt2.SETRANGE(ItemInfoExt2."Sub Type", ItemInfoExtend."Sub Type");
                    ItemInfoExt2.SETRANGE(ItemInfoExt2."No.", ItemInfoExtend."No.");
                    ItemInfoExt2.SETRANGE(ItemInfoExt2."Unit of Measure", ItemInfoExtend."Unit of Measure");
                    ItemInfoExt2.SETRANGE(ItemInfoExt2."Line No.", ItemInfoExtend."Line No." + 1, ItemInfoExtend."Line No." + 3);
                    IF ItemInfoExt2.FIND('-') THEN
                        REPEAT
                            IF ItemInfoExt2."Price Default" <> ItemInfoExtend."Price Default" THEN BEGIN
                                ItemInfoExt2."Price Default" := ItemInfoExtend."Price Default";
                                ItemInfoExt2."Price Inc. Disc. Default" := ItemInfoExtend."Price Default" - ROUND((ItemInfoExt2."Discount Default" / 100) * ItemInfoExtend."Price Default", 0.01);
                                ItemInfoExt2.MODIFY(TRUE);
                            END;
                        UNTIL ItemInfoExt2.NEXT = 0;
                END;
            UNTIL ItemPriceTmp[2].NEXT = 0;

        ItemPriceTmp[1].RESET;
        ItemPriceTmp[1].SETRANGE(ItemPriceTmp[1]."Line No.", 200);
        IF ItemPriceTmp[1].FIND('-') THEN
            REPEAT
                IF ItemInfoExtend.GET(ItemPriceTmp[1]."Entry Type", ItemPriceTmp[1]."Sub Type", ItemPriceTmp[1]."No."
                  , ItemPriceTmp[1]."Unit of Measure", ItemPriceTmp[1]."Line No.") THEN BEGIN
                    IF RecordTmpChanged(ItemPriceTmp[1], ItemInfoExtend) THEN BEGIN
                        ItemInfoExtend.TRANSFERFIELDS(ItemPriceTmp[1]);
                        ItemInfoExtend.MODIFY(TRUE);
                    END;
                    ItemInfoExt2.SETRANGE(ItemInfoExt2."Entry Type", ItemInfoExtend."Entry Type");
                    ItemInfoExt2.SETRANGE(ItemInfoExt2."Sub Type", ItemInfoExtend."Sub Type");
                    ItemInfoExt2.SETRANGE(ItemInfoExt2."No.", ItemInfoExtend."No.");
                    ItemInfoExt2.SETRANGE(ItemInfoExt2."Unit of Measure", ItemInfoExtend."Unit of Measure");
                    ItemInfoExt2.SETRANGE(ItemInfoExt2."Line No.", ItemInfoExtend."Line No." + 1, ItemInfoExtend."Line No." + 3);
                    IF ItemInfoExt2.FIND('-') THEN
                        REPEAT
                            IF ItemInfoExt2."Price Default" <> ItemInfoExtend."Price Default" THEN BEGIN
                                ItemInfoExt2."Price Default" := ItemInfoExtend."Price Default";
                                ItemInfoExt2."Price Inc. Disc. Default" := ItemInfoExtend."Price Default" - ROUND((ItemInfoExt2."Discount Default" / 100) * ItemInfoExtend."Price Default", 0.01);
                                ItemInfoExt2.MODIFY(TRUE);
                            END;
                        UNTIL ItemInfoExt2.NEXT = 0;
                END;
            UNTIL ItemPriceTmp[1].NEXT = 0;

        UpdateDTCommand(FALSE);
    end;

    procedure CreateItem(pItem: Record "Item"): Boolean
    var
        _Inserted: Boolean;
    begin
        CLEAR(_Inserted);
        ItemUnitofMeasure.RESET;
        ItemUnitofMeasure.SETRANGE(ItemUnitofMeasure."Item No.", Item."No.");
        IF ItemUnitofMeasure.FIND('-') THEN
            REPEAT
                IF NOT ItemInfoExtend.GET(ItemInfoExtend."Entry Type"::EcommerceItem, ItemInfoExtend."Sub Type"::ItemSetting
                  , ItemUnitofMeasure."Item No.", ItemUnitofMeasure.Code, 0) THEN BEGIN
                    CLEAR(ItemInfoExtend);
                    ItemInfoExtend.INIT;
                    ItemInfoExtend."Entry Type" := ItemInfoExtend."Entry Type"::EcommerceItem;
                    ItemInfoExtend."Sub Type" := ItemInfoExtend."Sub Type"::ItemSetting;
                    ItemInfoExtend."No." := ItemUnitofMeasure."Item No.";
                    ItemInfoExtend.VALIDATE("Unit of Measure", ItemUnitofMeasure.Code);
                    ItemInfoExtend."Hierarchy Parent Code" := pItem."LSC Retail Product Code";
                    ItemInfoExtend."Image Link" := ItemUnitofMeasure."Item No." + '.jpg';//Static
                    CheckOnInsertEcommItem(ItemInfoExtend);
                    ItemInfoExtend.INSERT(TRUE);

                    _Inserted := TRUE;
                END ELSE BEGIN
                    IF ItemInfoExtend."Hierarchy Parent Code" <> pItem."LSC Retail Product Code" THEN BEGIN
                        ItemInfoExtend."Hierarchy Parent Code" := pItem."LSC Retail Product Code";
                        ItemInfoExtend.MODIFY(TRUE);
                    END;
                END;
            UNTIL ItemUnitofMeasure.NEXT = 0;

        EXIT(_Inserted);
    end;

    procedure CreateItems()
    begin
        UpdateDTCommand(TRUE);
        COMMIT;

        Item.RESET;
        IF Item.FIND('-') THEN
            REPEAT
                CreateItem(Item);
            UNTIL (Item.NEXT = 0);

        CreateSetupStatic;
        UpdateDTCommand(FALSE);
    end;

    procedure CreateSetupStatic()
    begin
        CLEAR(ItemInfoExtendCopy);
        ItemInfoExtendCopy.INIT;
        ItemInfoExtendCopy."Entry Type" := ItemInfoExtendCopy."Entry Type"::EcommerceHierarchy;
        ItemInfoExtendCopy."Sub Type" := ItemInfoExtendCopy."Sub Type"::ItemSetting;
        ItemInfoExtendCopy."No." := '1000001';
        ItemInfoExtendCopy."Unit of Measure" := '';
        ItemInfoExtendCopy."Line No." := 0;
        ItemInfoExtendCopy.Description := Txt6;
        ItemInfoExtendCopy."Source Type" := ItemInfoExtendCopy."Source Type"::AutomaticStatic;
        ItemInfoExtendCopy."Item Type" := ItemInfoExtendCopy."Item Type"::Division;
        IF NOT ItemInfoExtend.GET(ItemInfoExtendCopy."Entry Type", ItemInfoExtendCopy."Sub Type", ItemInfoExtendCopy."No."
          , ItemInfoExtendCopy."Unit of Measure", ItemInfoExtendCopy."Line No.") THEN
            ItemInfoExtendCopy.INSERT(TRUE)
        ELSE
            IF RecordChanged(ItemInfoExtend, ItemInfoExtendCopy) THEN BEGIN
                ItemInfoExtendCopy."Image Link" := ItemInfoExtend."Image Link";
                ItemInfoExtendCopy.MODIFY(TRUE);
            END;
        CLEAR(ItemInfoExtendCopy);
        ItemInfoExtendCopy.INIT;
        ItemInfoExtendCopy."Entry Type" := ItemInfoExtendCopy."Entry Type"::EcommerceLimit;
        ItemInfoExtendCopy."Sub Type" := ItemInfoExtendCopy."Sub Type"::ItemSetting;
        ItemInfoExtendCopy."No." := 'ALL';
        ItemInfoExtendCopy.Quantity := 75;
        ItemInfoExtendCopy."Line No." := 0;
        ItemInfoExtendCopy."Source Type" := ItemInfoExtendCopy."Source Type"::AutomaticStatic;
        ItemInfoExtendCopy."Item Type" := ItemInfoExtendCopy."Item Type"::All;
        IF NOT ItemInfoExtend.GET(ItemInfoExtend."Entry Type"::EcommerceLimit, ItemInfoExtend."Sub Type"::ItemSetting, 'ALL', '', 0) THEN
            ItemInfoExtendCopy.INSERT(TRUE)
        ELSE
            IF RecordChanged(ItemInfoExtend, ItemInfoExtendCopy) THEN begin
                if ItemInfoExtendCopy."Starting Date" = 0D then
                    ItemInfoExtendCopy.Validate("Starting Date", 0D);
                ItemInfoExtendCopy.MODIFY(TRUE);
            end;

        ItemInfoExtendCopy.RESET;
        ItemInfoExtendCopy.SETRANGE(ItemInfoExtendCopy."Entry Type", ItemInfoExtendCopy."Entry Type"::EcommerceLimit);
        ItemInfoExtendCopy.SETRANGE(ItemInfoExtendCopy."Sub Type", ItemInfoExtendCopy."Sub Type"::ItemSetting);
        ItemInfoExtendCopy.SETRANGE(ItemInfoExtendCopy."Line No.", 10000);
        ItemInfoExtendCopy.SETRANGE(ItemInfoExtendCopy."Source Type", ItemInfoExtendCopy."Source Type"::AutomaticStatic);
        ItemInfoExtendCopy.SETFILTER(ItemInfoExtendCopy."Starting Date", '<%1', TODAY);
        IF ItemInfoExtendCopy.FIND('-') THEN
            REPEAT
                ItemInfoExtendCopy.DELETE(TRUE);
            UNTIL ItemInfoExtendCopy.NEXT = 0;
    end;

    procedure UpdateChanges(var Rec: Record "FSN Item Info. Extend")
    var
        BlockedUM: Boolean;
        ErrorTxt: Text[250];
        Description_: Text[250];
        ItemAttribVal: Record "LSC Attribute Value";
        TableSpecificInfocode_l: Record "LSC Table Specific Infocode";
        ItemStatusLinks: Record "LSC Item Status Link";
    begin
        BlockedUM := FALSE;
        IF GetItemDescriptionByUM(Rec."No.", Rec."Unit of Measure", Description_, ErrorTxt) THEN
            Rec.Description := Description_
        ELSE BEGIN
            BlockedUM := TRUE;
            Rec.Reason := ErrorTxt;
            Rec.Description := Description_
        END;

        IF NOT BlockedUM THEN
            IF BOUtil.IsBlockSaleOnPOS(Rec."No.", '', '', '', '', TODAY, ItemStatusLinks) THEN BEGIN
                Rec.Reason := Txt4;
                BlockedUM := TRUE;
            END;

        IF NOT BlockedUM THEN BEGIN
            IF Rec."Entry Type" = Rec."Entry Type"::EcommercePrices THEN BEGIN
                IF BOUtil.IsBlockPurchasing(Rec."No.", '', '', '', '', TODAY, ItemStatusLinks) OR
                  BOUtil.IsBlockTransfering(Rec."No.", '', '', '', '', TODAY, ItemStatusLinks) THEN BEGIN
                    Rec.Reason := ItemStatusLinks.TABLECAPTION + ' ' + ItemStatusLinks."Status Code";
                    BlockedUM := TRUE;
                END;
            END;
        END;

        Rec."Blocked Ecommerce" := BlockedUM;
        IF NOT Rec."Blocked Ecommerce" THEN
            Rec.Reason := '';

        IF Item."No." <> Rec."No." THEN
            Item.GET(Rec."No.");
        Rec."Hierarchy Parent Code" := Item."LSC Retail Product Code";
        Rec."Mark Code" := GetItemAttrib1CodeClear(Item."LSC Attrib 1 Code");
        Rec."Require Medical Document" := Item."LSC Retail Product Code" = '01002002';

        IF NOT Rec."Require Medical Document" THEN BEGIN
            Rec."Require Medical Document" := Item."LSC Attrib 2 Code" IN ['CONTROLADOS', 'MONOFARMACO-CONTROLADO', 'POLIFARMACO-CONTROLADO'];
        END;

        IF NOT Rec."Require Medical Document" THEN BEGIN
            ItemAttribVal.RESET;
            ItemAttribVal.SETRANGE(ItemAttribVal."Link Field 1", Rec."No.");
            ItemAttribVal.SETRANGE(ItemAttribVal."Attribute Code", 'RECETAS');
            Rec."Require Medical Document" := ItemAttribVal.FINDFIRST;
        END;
        IF NOT Rec."Require Medical Document" THEN BEGIN
            TableSpecificInfocode_l.SETRANGE(TableSpecificInfocode_l."Table ID", 27);
            TableSpecificInfocode_l.SETRANGE(TableSpecificInfocode_l.Value, Rec."No.");
            TableSpecificInfocode_l.SETRANGE(TableSpecificInfocode_l."Infocode Code", 'RECETA');
            TableSpecificInfocode_l.SETRANGE(TableSpecificInfocode_l.Sequence, 0);
            Rec."Require Medical Document" := TableSpecificInfocode_l.FINDFIRST;
        END;
        IF Rec."Entry Type" = Rec."Entry Type"::EcommerceItem THEN
            Rec.ID := 'RETAIL';
        Rec."Source Type" := Rec."Source Type"::Automatic;
    end;

    procedure UpdateHierarchy()
    var
        Division_l: Record "LSC Division";
        ProductGroup_l: Record "LSC Retail Product Group";
        ItemCategory_l: Record "Item Category";
        BlockDiscountVisible: Boolean;
        BlockEcommerce: Boolean;
    begin
        UpdateDTCommand(TRUE);
        COMMIT;
        ItemInfoExtendCopy.INIT;
        ItemInfoExtendCopy."Entry Type" := ItemInfoExtendCopy."Entry Type"::EcommerceHierarchy;
        ItemInfoExtendCopy."Sub Type" := ItemInfoExtendCopy."Sub Type"::ItemSetting;
        ItemInfoExtendCopy."Unit of Measure" := '';
        ItemInfoExtendCopy."Line No." := 0;
        ItemInfoExtendCopy."Source Type" := ItemInfoExtendCopy."Source Type"::Automatic;

        Division_l.RESET;
        IF Division_l.FIND('-') THEN
            REPEAT
                ItemInfoExtendCopy."No." := Division_l.Code;
                ItemInfoExtendCopy.Description := Division_l.Description;
                ItemInfoExtendCopy."Hierarchy Parent Code" := '';
                ItemInfoExtendCopy."Item Type" := ItemInfoExtendCopy."Item Type"::Division;
                ItemInfoExtendCopy."Require Medical Document" := FALSE;
                IF NOT ItemInfoExtend.GET(ItemInfoExtend."Entry Type"::EcommerceHierarchy, ItemInfoExtend."Sub Type"::ItemSetting, Division_l.Code, '', 0) THEN
                    ItemInfoExtendCopy.INSERT(TRUE)
                ELSE
                    IF ValidateExpireDT(ItemInfoExtend) OR ((ItemInfoExtend."Starting Date" = 0D) AND (ItemInfoExtend."Ending Date" = 0D)) THEN
                        IF RecordChanged(ItemInfoExtendCopy, ItemInfoExtend) THEN BEGIN
                            ItemInfoExtendCopy."Image Link" := ItemInfoExtend."Image Link";

                            ItemInfoExtend.INIT;
                            ItemInfoExtend := ItemInfoExtendCopy;
                            ItemInfoExtend.MODIFY(TRUE);
                        END;

                BlockDiscountVisible := GetCurrHierarchyBlock(TRUE);
                BlockEcommerce := GetCurrHierarchyBlock(FALSE);
                ItemCategory_l.RESET;
                ItemCategory_l.SETRANGE(ItemCategory_l."LSC Division Code", Division_l.Code);
                IF ItemCategory_l.FIND('-') THEN
                    REPEAT
                        ItemInfoExtendCopy."No." := ItemCategory_l.Code;
                        ItemInfoExtendCopy.Description := ItemCategory_l.Description;
                        ItemInfoExtendCopy."Hierarchy Parent Code" := Division_l.Code;
                        ItemInfoExtendCopy."Item Type" := ItemInfoExtendCopy."Item Type"::Category;
                        ItemInfoExtendCopy."Require Medical Document" := BlockDiscountVisible;
                        ItemInfoExtendCopy."Blocked Ecommerce" := BlockEcommerce;
                        IF NOT ItemInfoExtend.GET(ItemInfoExtend."Entry Type"::EcommerceHierarchy, ItemInfoExtend."Sub Type"::ItemSetting, ItemCategory_l.Code, '', 0) THEN
                            ItemInfoExtendCopy.INSERT(TRUE)
                        ELSE
                            IF ValidateExpireDT(ItemInfoExtend) OR ((ItemInfoExtend."Starting Date" = 0D) AND (ItemInfoExtend."Ending Date" = 0D)) THEN
                                IF RecordChanged(ItemInfoExtendCopy, ItemInfoExtend) THEN BEGIN
                                    ItemInfoExtendCopy."Image Link" := ItemInfoExtend."Image Link";

                                    ItemInfoExtend.INIT;
                                    ItemInfoExtend := ItemInfoExtendCopy;
                                    ItemInfoExtend.MODIFY(TRUE);
                                END;

                        BlockDiscountVisible := GetCurrHierarchyBlock(TRUE);
                        BlockEcommerce := GetCurrHierarchyBlock(FALSE);
                        ProductGroup_l.RESET;
                        ProductGroup_l.SETRANGE(ProductGroup_l."Item Category Code", ItemCategory_l.Code);
                        ProductGroup_l.SETRANGE(ProductGroup_l."Division Code", Division_l.Code);
                        IF ProductGroup_l.FIND('-') THEN
                            REPEAT
                                ItemInfoExtendCopy."No." := ProductGroup_l.Code;
                                ItemInfoExtendCopy."Hierarchy Parent Code" := ItemCategory_l.Code;
                                ItemInfoExtendCopy."Item Type" := ItemInfoExtend."Item Type"::ProductGroup;
                                ItemInfoExtendCopy.Description := ProductGroup_l.Description;
                                ItemInfoExtendCopy."Require Medical Document" := BlockDiscountVisible;
                                ItemInfoExtendCopy."Blocked Ecommerce" := BlockEcommerce;
                                IF NOT ItemInfoExtend.GET(ItemInfoExtend."Entry Type"::EcommerceHierarchy, ItemInfoExtend."Sub Type"::ItemSetting, ProductGroup_l.Code, '', 0) THEN
                                    ItemInfoExtendCopy.INSERT(TRUE)
                                ELSE
                                    IF ValidateExpireDT(ItemInfoExtend) OR ((ItemInfoExtend."Starting Date" = 0D) AND (ItemInfoExtend."Ending Date" = 0D)) THEN
                                        IF RecordChanged(ItemInfoExtendCopy, ItemInfoExtend) THEN BEGIN
                                            ItemInfoExtendCopy."Image Link" := ItemInfoExtend."Image Link";

                                            ItemInfoExtend.INIT;
                                            ItemInfoExtend := ItemInfoExtendCopy;
                                            ItemInfoExtend.MODIFY(TRUE);
                                        END;
                            UNTIL ProductGroup_l.NEXT = 0;
                    UNTIL ItemCategory_l.NEXT = 0;
            UNTIL Division_l.NEXT = 0;

        UpdateDTCommand(TRUE);
    end;

    procedure CalcOffercLine(var ItemInfoExtEcommerceItem: Record "FSN Item Info. Extend" temporary; pCustomerDiscGroupCode: Code[20]; pTenderTypeCode: Code[10])
    var
        LineDisc: Decimal;
        LinePrice: Decimal;
        POSTransLineTmp: Record "LSC POS Trans. Line" temporary;
        OfferDisc: Decimal;
        OfferPrice: Decimal;
        BlockTenderOffer: Boolean;
        PriceBase: Decimal;
    begin
        CLEAR(LineDisc);
        CLEAR(LinePrice);
        CLEAR(OfferDisc);
        CLEAR(OfferPrice);
        PosFuncProfile.GET('##DEFAULT');

        POSTransLineTmp."Store No." := GlobalStore;
        POSTransLineTmp."POS Terminal No." := GlobalPOS;
        POSTransLineTmp."Line No." := 1;
        POSTransLineTmp."Entry Type" := POSTransLineTmp."Entry Type"::Item;
        POSTransLineTmp."Unit of Measure" := ItemInfoExtEcommerceItem."Unit of Measure";
        POSTransLineTmp."Sales Staff" := GlobalStaff;
        POSTransLineTmp.Number := ItemInfoExtEcommerceItem."No.";
        POSTransLineTmp."Sales Type" := 'POS';
        POSTransLineTmp."Price Group Code" := '';

        POSTransLineTmp.Price :=
          RetailPriceUtil.GetValidRetailPrice2(GlobalStore, ItemInfoExtEcommerceItem."No.", GlobalDate, GlobalTime, ItemInfoExtEcommerceItem."Unit of Measure",
              '', VatSetup."VAT Bus. Posting Group", '', POSTransLineTmp."Price Group Code", 'POS', pCustomerDiscGroupCode);

        IF POSTransLineTmp.Price <= 0 THEN BEGIN
            ItemInfoExtEcommerceItem."Price Default" := 0;
            ItemInfoExtEcommerceItem."Price Inc. Disc. Default" := 0;
            ItemInfoExtEcommerceItem."Discount Default" := 0;
            ItemInfoExtEcommerceItem."Blocked Ecommerce" := TRUE;
            ItemInfoExtEcommerceItem.Reason := STRSUBSTNO(Txt5, FORMAT(ItemInfoExtEcommerceItem."Price Default"));
            EXIT;
        END;

        IF Item."VAT Prod. Posting Group" = '' THEN BEGIN
            ItemInfoExtEcommerceItem."Blocked Ecommerce" := TRUE;
            ItemInfoExtEcommerceItem.Reason := STRSUBSTNO(Txt3, Item.TABLECAPTION, Item.FIELDCAPTION("VAT Prod. Posting Group"));
            EXIT;
        END;

        IF NOT ValidateDateTimeRecord(ItemInfoExtEcommerceItem) THEN BEGIN
            IF POSTransLineTmp.Price <> ItemInfoExtEcommerceItem."Price Default" THEN BEGIN
                ItemInfoExtEcommerceItem."Price Default" := POSTransLineTmp.Price;
                ItemInfoExtEcommerceItem."Price Inc. Disc. Default" := POSTransLineTmp.Price - ROUND((ItemInfoExtEcommerceItem."Discount Default" / 100) * POSTransLineTmp.Price, 0.01);
            END;
        END ELSE BEGIN

            FindPeriodicOffers(POSTransLineTmp, pCustomerDiscGroupCode, OfferDisc, OfferPrice, BlockTenderOffer, FALSE, PriceBase, pTenderTypeCode); //Offer Disc. & Multybuy
            FindPeriodicOffers(POSTransLineTmp, pCustomerDiscGroupCode, LineDisc, LinePrice, BlockTenderOffer, TRUE, PriceBase, pTenderTypeCode); //Tender Offer %

            IF NOT (ItemInfoExtEcommerceItem."Entry Type" = ItemInfoExtEcommerceItem."Entry Type"::EcommercePrices) THEN
                ItemInfoExtEcommerceItem.ID := pCustomerDiscGroupCode;
            ItemInfoExtEcommerceItem."Price Default" := POSTransLineTmp.Price;
            ItemInfoExtEcommerceItem."Price Inc. Disc. Default" := POSTransLineTmp.Price;
            ItemInfoExtEcommerceItem."Discount Default" := 0;
            IF OfferDisc > 0 THEN BEGIN
                IF (PriceBase = POSTransLineTmp.Price) AND (OfferPrice > 0) THEN BEGIN
                    ItemInfoExtEcommerceItem."Price Inc. Disc. Default" := ROUND(OfferPrice, 0.01);
                    ItemInfoExtEcommerceItem."Discount Default" := OfferDisc;
                END ELSE BEGIN
                    ItemInfoExtEcommerceItem."Price Inc. Disc. Default" := POSTransLineTmp.Price - ROUND((OfferDisc / 100) * POSTransLineTmp.Price, 0.01);
                    ItemInfoExtEcommerceItem."Discount Default" := ROUND((1 - (ItemInfoExtEcommerceItem."Price Inc. Disc. Default" / POSTransLineTmp.Price)) * 100, 1);
                END;
                ItemInfoExtEcommerceItem."Price Inc. Disc. Default" := POSTransLineTmp.Price - ROUND((OfferDisc / 100) * POSTransLineTmp.Price, 0.01);
                ItemInfoExtEcommerceItem."Discount Default" := ROUND((1 - (ItemInfoExtEcommerceItem."Price Inc. Disc. Default" / POSTransLineTmp.Price)) * 100, 1);
            END;
            IF LineDisc > 0 THEN BEGIN
                IF RetailSetup."FSN Disc. Tender In Base" THEN BEGIN
                    ItemInfoExtEcommerceItem."Price Inc. Disc. Default" :=
                      ItemInfoExtEcommerceItem."Price Inc. Disc. Default" - ROUND((LineDisc / 100) * POSTransLineTmp.Price, 0.01);
                    LineDisc := LineDisc + OfferDisc;
                    ItemInfoExtEcommerceItem."Discount Default" := LineDisc;
                END ELSE
                    IF OfferDisc <= 0 THEN BEGIN
                        ItemInfoExtEcommerceItem."Discount Default" := LineDisc;
                        ItemInfoExtEcommerceItem."Price Inc. Disc. Default" := POSTransLineTmp.Price - ROUND((LineDisc / 100) * ItemInfoExtEcommerceItem."Price Inc. Disc. Default", 0.01);
                    END ELSE BEGIN
                        ItemInfoExtEcommerceItem."Price Inc. Disc. Default" := ROUND((1 - (LineDisc / 100)) * ItemInfoExtEcommerceItem."Price Inc. Disc. Default", 0.01);
                        ItemInfoExtEcommerceItem."Discount Default" := ROUND((1 - (ItemInfoExtEcommerceItem."Price Inc. Disc. Default" / POSTransLineTmp.Price)) * 100, 1);
                    END;
            END;
        END;
        ItemInfoExtEcommerceItem."Price Default" := ROUND(ItemInfoExtEcommerceItem."Price Default", 0.01);
        ItemInfoExtEcommerceItem."Price Inc. Disc. Default" := ROUND(ItemInfoExtEcommerceItem."Price Inc. Disc. Default", 0.01);
        ItemInfoExtEcommerceItem."Discount Default" := ROUND(ItemInfoExtEcommerceItem."Discount Default", 0.01);

    end;

    procedure GetItemDescriptionByUM(No: Code[20]; UnitOfMeasure: Code[10]; var pDescription: Text[250]; var pErrorTxt: Text[250]): Boolean
    var
        TableSpecificInfocode_l: Record "LSC Table Specific Infocode";
        ItemBarcodes: Record "LSC Barcodes";
    begin
        CLEAR(pDescription);
        ItemBarcodes.RESET;
        ItemBarcodes.SETCURRENTKEY("Item No.", "Variant Code", "Unit of Measure Code");
        ItemBarcodes.SETRANGE(ItemBarcodes."Item No.", No);
        ItemBarcodes.SETRANGE(ItemBarcodes."Unit of Measure Code", UnitOfMeasure);
        IF ItemBarcodes.FINDFIRST THEN
            IF false THEN BEGIN                         //field not exists
                //IF ItemBarcodes.Blocked THEN BEGIN    //field not exists
                IF ItemUnitofMeasure.GET(No, UnitOfMeasure) AND
                  Item.GET(No) AND
                  (Item."Purch. Unit of Measure" = UnitOfMeasure) AND
                  ((Item."LSC Retail Product Code" IN ['01002001', '01002002']) OR
                  (Item."LSC Attrib 2 Code" IN ['CONTROLADOS', 'MONOFARMACO-CONTROLADO', 'POLIFARMACO-CONTROLADO']))
                THEN BEGIN
                    pDescription := ItemBarcodes.Description;
                    EXIT(TRUE);
                END;
                pDescription := ItemBarcodes.Description;
                //pErrorTxt := ItemBarcodes.TABLECAPTION + ' ' + ItemBarcodes.FIELDCAPTION(ItemBarcodes.Blocked);
                pErrorTxt := 'Not used in BC';
                EXIT(FALSE);
            END ELSE BEGIN
                pDescription := ItemBarcodes.Description;
                EXIT(TRUE);
            END;

        pErrorTxt := COPYSTR(STRSUBSTNO(Txt3, ItemInfoExtend.FIELDCAPTION(ItemInfoExtend."Unit of Measure")
             , ItemInfoExtend.FIELDCAPTION(ItemInfoExtend.Description)), 1, MAXSTRLEN(ItemInfoExtend.Reason));
        EXIT(FALSE);
    end;

    procedure GetItemIngredient(ItemNo: Code[20]) result: Text[200]
    var
        IngredientesItem: Record "FSN Ingredient Item Link";
        Ingredient: Record "FSN Ingredient";
    begin
        IF ItemNo <> GlobalExtTxtArr[1] [1] THEN BEGIN
            GlobalExtTxtArr[1] [1] := ItemNo;
            GlobalExtTxtArr[1] [2] := '';
        END ELSE BEGIN
            IF GlobalExtTxtArr[1] [2] <> '' THEN BEGIN
                result := GlobalExtTxtArr[1] [2];
                EXIT;
            END;
        END;
        CLEAR(result);
        IngredientesItem.RESET;
        IngredientesItem.SETRANGE(IngredientesItem.ItemNo, ItemNo);
        IF IngredientesItem.FIND('-') THEN
            REPEAT
                IF Ingredient.GET(IngredientesItem.Ingrediente) THEN
                    IF STRLEN(result) + STRLEN(Ingredient.Description) + 1 < 200 THEN
                        IF result <> '' THEN
                            result += ',' + Ingredient.Description
                        ELSE
                            result += Ingredient.Description;
            UNTIL IngredientesItem.NEXT = 0;

        result := DELCHR(result, '=', '"<>');
        GlobalExtTxtArr[1] [2] := result;
    end;

    procedure GetItemInfoExtend(ItemNo: Code[20]; UM: Code[10]) result: Text[500]
    var
        InfoExtend: Record "FSN Item Info. Extend";
        InfoID: Code[20];
    begin
        IF ItemNo <> GlobalExtTxtArr[2] [1] THEN BEGIN
            GlobalExtTxtArr[2] [1] := ItemNo;
            GlobalExtTxtArr[2] [2] := '';
        END ELSE BEGIN
            IF GlobalExtTxtArr[2] [2] <> '' THEN BEGIN
                result := GlobalExtTxtArr[2] [2];
                EXIT;
            END;
        END;
        CLEAR(result);
        InfoExtend.RESET;
        ItemInfoExtend.SETCURRENTKEY("Entry Type", "Sub Type", "No.", "Unit of Measure", "Line No.");
        InfoExtend.SETRANGE(InfoExtend."Entry Type", InfoExtend."Entry Type"::ItemInformation);
        InfoExtend.SETRANGE(InfoExtend."Sub Type", InfoExtend."Sub Type"::Information);
        InfoExtend.SETRANGE(InfoExtend."No.", ItemNo);
        InfoExtend.SETRANGE(InfoExtend.ID, 'INDICACIONES');
        IF UM <> '' THEN
            InfoExtend.SETRANGE(InfoExtend."Unit of Measure", UM);
        IF InfoExtend.FIND('-') THEN BEGIN
            result := InfoExtend.ID + ' ';
            REPEAT
                IF STRLEN(InfoExtend."Free Text") + STRLEN(result) + 1 <= 500 THEN
                    result += InfoExtend."Free Text";
            UNTIL InfoExtend.NEXT = 0;
        END;
        result := DELCHR(result, '=', '"<>');
        GlobalExtTxtArr[2] [2] := result;
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

    procedure GetCurrHierarchyBlock(CheckDiscount: Boolean): Boolean
    var
        Exit_: Boolean;
        Block: Boolean;
    begin
        CLEAR(Block);
        CLEAR(Exit_);
        ItemInfoExt2.RESET;
        ItemInfoExt2.SETCURRENTKEY("Entry Type", "Sub Type", "No.", "Unit of Measure", "Line No.");
        ItemInfoExt2.SETRANGE(ItemInfoExt2."Entry Type", ItemInfoExtendCopy."Entry Type");
        ItemInfoExt2.SETRANGE(ItemInfoExt2."Sub Type", ItemInfoExtendCopy."Sub Type");
        ItemInfoExt2.SETRANGE(ItemInfoExt2."No.", ItemInfoExtendCopy."No.");
        ItemInfoExt2.SETRANGE(ItemInfoExt2."Item Type", ItemInfoExtendCopy."Item Type");
        ItemInfoExt2.SETRANGE(ItemInfoExt2."Unit of Measure", '');
        IF ItemInfoExt2.FIND('+') THEN
            REPEAT
                IF ValidateDateTimeRecord(ItemInfoExt2) THEN BEGIN
                    Exit_ := TRUE;
                    IF NOT CheckDiscount THEN
                        Block := ItemInfoExt2."Blocked Ecommerce"
                    ELSE
                        Block := ItemInfoExt2."Require Medical Document";
                END;
            UNTIL (ItemInfoExt2.NEXT(-1) = 0) OR Exit_;

        EXIT(Block);
    end;

    procedure GetEcomPriceTmp1FromEcomItem(Rec: Record "FSN Item Info. Extend"; LineDiscGroup: Integer; var RecCopyTmp: Record "FSN Item Info. Extend" temporary; var IsNew: Boolean; NewID: Code[20])
    begin
        //CLEAR(IsNew);
        //CLEAR(NewID);

        /*CASE LineDiscGroup OF
            0:
                NewID := 'VIP';
            100:
                NewID := 'HUGO';
        END;*///From extension

        IF NOT RecCopyTmp.GET(Rec."Entry Type"::EcommercePrices, Rec."Sub Type"::ItemSetting
          , Rec."No.", Rec."Unit of Measure", LineDiscGroup) THEN BEGIN
            RecCopyTmp.INIT;
            RecCopyTmp."Entry Type" := RecCopyTmp."Entry Type"::EcommercePrices;
            RecCopyTmp."Sub Type" := RecCopyTmp."Sub Type"::ItemSetting;
            RecCopyTmp."No." := Rec."No.";
            RecCopyTmp."Unit of Measure" := Rec."Unit of Measure";
            RecCopyTmp."Source Type" := RecCopyTmp."Source Type"::Automatic;
            RecCopyTmp."Line No." := LineDiscGroup;//For VIP
            RecCopyTmp.ID := NewID;
            RecCopyTmp.INSERT();
            //IsNew := TRUE;
        END;
        IF RecCopyTmp.ID <> NewID THEN BEGIN
            RecCopyTmp.ID := NewID;
            RecCopyTmp.MODIFY();
        END;
    end;

    procedure GetIDParameter(No_: Code[30]; ValueForDefault: Code[20]): Code[20]
    begin
        GlobalParametersSetup.SETRANGE(GlobalParametersSetup."No.", No_);
        IF GlobalParametersSetup.FIND('-') AND (GlobalParametersSetup.ID <> '') THEN
            EXIT(GlobalParametersSetup.ID);

        EXIT(ValueForDefault);
    end;

    procedure RecordTmpChanged(RecNewTmp: Record "FSN Item Info. Extend" temporary; RecOld: Record "FSN Item Info. Extend"): Boolean
    begin
        IF (RecNewTmp.ID <> RecOld.ID) OR
          (RecNewTmp.Quantity <> RecOld.Quantity) OR
          (RecNewTmp.Description <> RecOld.Description) OR
          (RecNewTmp."Free Text" <> RecOld."Free Text") OR
          (RecNewTmp.Sort <> RecOld.Sort) OR
          (RecNewTmp."Blocked Ecommerce" <> RecOld."Blocked Ecommerce") OR
          (RecNewTmp.Reason <> RecOld.Reason) OR
          (RecNewTmp."Starting Date" <> RecOld."Starting Date") OR
          (RecNewTmp."Start Time" <> RecOld."Start Time") OR
          (RecNewTmp."Ending Date" <> RecOld."Ending Date") OR
          (RecNewTmp."End Time" <> RecOld."End Time") OR
          (RecNewTmp."Source Type" <> RecOld."Source Type") OR
          (RecNewTmp."Item Type" <> RecOld."Item Type") OR
          (RecNewTmp."Hierarchy Parent Code" <> RecOld."Hierarchy Parent Code") OR
          (RecNewTmp."Minimum Quantity Sale" <> RecOld."Minimum Quantity Sale") OR
          (RecNewTmp."Maximum Quantity Sale" <> RecOld."Maximum Quantity Sale") OR
          (RecNewTmp."Require Medical Document" <> RecOld."Require Medical Document") OR
          (RecNewTmp."Price Default" <> RecOld."Price Default") OR
          (RecNewTmp."Price Inc. Disc. Default" <> RecOld."Price Inc. Disc. Default") OR
          (RecNewTmp."Discount Default" <> RecOld."Discount Default") OR
          (RecNewTmp."Tag Discount Default" <> RecOld."Tag Discount Default") OR
          (RecNewTmp."Mark Code" <> RecOld."Mark Code") THEN
            EXIT(TRUE)
        ELSE
            EXIT(FALSE);
    end;

    procedure RecordChanged(RecNew: Record "FSN Item Info. Extend"; RecOld: Record "FSN Item Info. Extend"): Boolean
    begin
        IF (RecNew.ID <> RecOld.ID) OR
          (RecNew.Quantity <> RecOld.Quantity) OR
          (RecNew.Description <> RecOld.Description) OR
          (RecNew."Free Text" <> RecOld."Free Text") OR
          (RecNew.Sort <> RecOld.Sort) OR
          (RecNew."Blocked Ecommerce" <> RecOld."Blocked Ecommerce") OR
          (RecNew.Reason <> RecOld.Reason) OR
          (RecNew."Starting Date" <> RecOld."Starting Date") OR
          (RecNew."Start Time" <> RecOld."Start Time") OR
          (RecNew."Ending Date" <> RecOld."Ending Date") OR
          (RecNew."End Time" <> RecOld."End Time") OR
          (RecNew."Source Type" <> RecOld."Source Type") OR
          (RecNew."Item Type" <> RecOld."Item Type") OR
          (RecNew."Hierarchy Parent Code" <> RecOld."Hierarchy Parent Code") OR
          (RecNew."Minimum Quantity Sale" <> RecOld."Minimum Quantity Sale") OR
          (RecNew."Maximum Quantity Sale" <> RecOld."Maximum Quantity Sale") OR
          (RecNew."Require Medical Document" <> RecOld."Require Medical Document") OR
          (RecNew."Price Default" <> RecOld."Price Default") OR
          (RecNew."Price Inc. Disc. Default" <> RecOld."Price Inc. Disc. Default") OR
          (RecNew."Discount Default" <> RecOld."Discount Default") OR
          (RecNew."Tag Discount Default" <> RecOld."Tag Discount Default") OR
          (RecNew."Mark Code" <> RecOld."Mark Code") THEN
            EXIT(TRUE)
        ELSE
            EXIT(FALSE);
    end;

    procedure TestingPrice(pItemTest: Code[20])
    var
        TableCaptionBlock: Text[50];
        BlockFromHierarchy: Boolean;
        SetupHierarchy: Record "FSN Item Info. Extend";
        HierarchyActiveTMP: Record "FSN Item Info. Extend" temporary;
        Expired: Boolean;
        OkDateTime: Boolean;
        i: Integer;
        ParentActive: Boolean;
        TenderCode: Code[20];
        IsNew: Boolean;
        UMExists: Boolean;
        ItemPriceTmp: array[2] of Record "FSN Item Info. Extend" temporary;
    begin
        COMMIT;

        IF NOT InicializeParameters THEN
            EXIT;

        IF NOT Customer.GET(GetIDParameter('ECUST', '')) THEN BEGIN
            Customer.RESET;
            Customer.SETRANGE(Customer."Customer Disc. Group", 'RETAIL');
            IF NOT Customer.FINDFIRST THEN BEGIN
                Customer.RESET;
                Customer.FINDFIRST;
            END;
        END;

        ClearRecordExpire(GlobalDate);

        HierarchyActiveTMP.RESET;
        HierarchyActiveTMP.DELETEALL;

        FOR i := 3 DOWNTO 1 DO BEGIN
            SetupHierarchy.RESET;
            SetupHierarchy.SETRANGE(SetupHierarchy."Entry Type", SetupHierarchy."Entry Type"::EcommerceHierarchy);
            SetupHierarchy.SETRANGE(SetupHierarchy."Sub Type", SetupHierarchy."Sub Type"::ItemSetting);
            SetupHierarchy.SETRANGE(SetupHierarchy."Item Type", i); //Item type
            SetupHierarchy.SETFILTER(SetupHierarchy."Line No.", '>0');
            IF SetupHierarchy.FIND('-') THEN
                REPEAT
                    CLEAR(ParentActive);
                    IF i = 3 THEN
                        ParentActive := NOT SetupHierarchy."Blocked Ecommerce"
                    ELSE BEGIN
                        ParentActive := HierarchyActiveTMP.GET(SetupHierarchy."Entry Type", SetupHierarchy."Sub Type"
                            , SetupHierarchy."Hierarchy Parent Code", SetupHierarchy."Unit of Measure", 0) AND NOT HierarchyActiveTMP."Blocked Ecommerce";
                    END;
                    IF ParentActive THEN
                        IF ValidateDateTimeRecord(SetupHierarchy) THEN
                            IF NOT HierarchyActiveTMP.GET(SetupHierarchy."Entry Type", SetupHierarchy."Sub Type"
                              , SetupHierarchy."No.", SetupHierarchy."Unit of Measure", 0) THEN BEGIN
                                HierarchyActiveTMP := SetupHierarchy;
                                HierarchyActiveTMP."Line No." := 0;
                                HierarchyActiveTMP.INSERT;
                            END;
                UNTIL SetupHierarchy.NEXT = 0;
            SetupHierarchy.SETRANGE(SetupHierarchy."Line No.", 0);
            IF SetupHierarchy.FIND('-') THEN
                REPEAT
                    CLEAR(ParentActive);
                    IF i = 3 THEN
                        ParentActive := NOT SetupHierarchy."Blocked Ecommerce"
                    ELSE BEGIN
                        ParentActive := HierarchyActiveTMP.GET(SetupHierarchy."Entry Type", SetupHierarchy."Sub Type"
                            , SetupHierarchy."Hierarchy Parent Code", SetupHierarchy."Unit of Measure", 0) AND NOT HierarchyActiveTMP."Blocked Ecommerce";
                    END;
                    IF ParentActive THEN
                        IF ValidateDateTimeRecord(SetupHierarchy) THEN
                            IF NOT HierarchyActiveTMP.GET(SetupHierarchy."Entry Type", SetupHierarchy."Sub Type"
                              , SetupHierarchy."No.", SetupHierarchy."Unit of Measure", 0) THEN BEGIN
                                HierarchyActiveTMP := SetupHierarchy;
                                HierarchyActiveTMP."Line No." := 0;
                                HierarchyActiveTMP.INSERT;
                            END;
                UNTIL SetupHierarchy.NEXT = 0;
        END;

        FillItemInfoExtTmp;
        ItemInfoExtPricesTmp.RESET;
        ItemInfoExtPricesTmp.DELETEALL;
        CLEAR(ItemInfoExtPricesTmp);
        ItemPriceTmp[1].RESET;
        ItemPriceTmp[1].DELETEALL;
        ItemPriceTmp[2].RESET;
        ItemPriceTmp[2].DELETEALL;
        CLEAR(ItemPriceTmp[1]);
        CLEAR(ItemPriceTmp[2]);

        RetailSetup.GET;
        ItemInfoExtTmp.RESET;
        ItemInfoExtTmp.SETRANGE(ItemInfoExtTmp."Line No.", 0);
        ItemInfoExtTmp.SETRANGE(ItemInfoExtTmp."No.", pItemTest);
        IF ItemInfoExtTmp.FIND('-') THEN
            REPEAT
                CLEAR(TableCaptionBlock);
                CLEAR(BlockFromHierarchy);

                Expired := ValidateExpireDT(ItemInfoExtTmp);

                IF NOT HierarchyActiveTMP.GET(HierarchyActiveTMP."Entry Type"::EcommerceHierarchy
                                        , HierarchyActiveTMP."Sub Type"::ItemSetting
                                        , ItemInfoExtTmp."Hierarchy Parent Code", '', 0) THEN BEGIN
                    BlockFromHierarchy := TRUE;
                    TableCaptionBlock := COPYSTR(STRSUBSTNO(Txt8, ItemInfoExtTmp.FIELDCAPTION("Hierarchy Parent Code"), Txt9, ''), 1, 50);
                END;

                IF NOT BlockFromHierarchy THEN
                    IF ItemBlockedTmp.GET(ItemBlockedTmp."Entry Type"::EcommerceLimit, ItemBlockedTmp."Sub Type"::Information, ItemInfoExtTmp."No.", ItemInfoExtTmp."Unit of Measure", 0) THEN BEGIN
                        BlockFromHierarchy := TRUE;
                        TableCaptionBlock := ItemBlockedTmp.Reason;
                    END;

                UMExists := TRUE;
                IF NOT ItemUnitofMeasure.GET(ItemInfoExtTmp."No.", ItemInfoExtTmp."Unit of Measure") THEN BEGIN
                    BlockFromHierarchy := TRUE;
                    TableCaptionBlock := STRSUBSTNO(Txt3, '', ItemUnitofMeasure.TABLECAPTION);
                    UMExists := FALSE;
                END;

                IF (BlockFromHierarchy) THEN BEGIN
                    IF NOT ItemInfoExtTmp."Blocked Ecommerce" THEN BEGIN
                        ItemInfoExtTmp.VALIDATE("Starting Date", 0D);
                        ItemInfoExtTmp.VALIDATE("Ending Date", 0D);
                        ItemInfoExtTmp.Reason := TableCaptionBlock;
                        ItemInfoExtTmp."Blocked Ecommerce" := TRUE;
                        ItemInfoExtTmp.MODIFY;
                    END ELSE
                        IF ItemInfoExtTmp.Reason <> TableCaptionBlock THEN BEGIN
                            ItemInfoExtTmp.Reason := TableCaptionBlock;
                            ItemInfoExtTmp.MODIFY;
                        END;
                END ELSE BEGIN
                    IF Expired THEN BEGIN
                        ItemInfoExtTmp.VALIDATE("Starting Date", 0D);
                        ItemInfoExtTmp.VALIDATE("Ending Date", 0D);
                        ItemInfoExtTmp.MODIFY;
                    END;

                    OkDateTime := ValidateDateTimeRecord(ItemInfoExtTmp);
                    IF OkDateTime THEN BEGIN
                        UpdateChanges(ItemInfoExtTmp);
                        ItemInfoExtTmp.MODIFY;
                    END;
                END;

                //Disc
                IF UMExists THEN BEGIN
                    IF Item."No." <> ItemInfoExtTmp."No." THEN
                        IF Item.GET(ItemInfoExtTmp."No.") THEN;
                    IF Customer."VAT Bus. Posting Group" = '' THEN
                        Customer."VAT Bus. Posting Group" := Store."Store VAT Bus. Post. Gr.";
                    IF NOT VatSetup.GET(Customer."VAT Bus. Posting Group", Item."VAT Prod. Posting Group") THEN
                        VatSetup.INIT;

                    TenderCode := GetIDParameter('EMPRETAIL', '20');
                    CalcOffercLine(ItemInfoExtTmp, 'RETAIL', TenderCode);
                    ItemInfoExtTmp.MODIFY;

                    TenderCode := GetIDParameter('EMPVIP', '20');
                    GetEcomPrice1FromEcomItem(ItemInfoExtTmp, 0, ItemInfoExtendCopy, IsNew, 'VIP');
                    ItemPriceTmp[2] := ItemInfoExtendCopy;
                    ItemPriceTmp[2].INSERT;
                    CalcOffercLine(ItemPriceTmp[2], 'VIP', TenderCode);
                    ItemPriceTmp[2].MODIFY;

                    TenderCode := GetIDParameter('EMPBAVIP', '5');//Temp
                    GetEcomPrice1FromEcomItem(ItemInfoExtTmp, 200, ItemInfoExtendCopy, IsNew, 'VIP_BA');//Static Line
                    ItemPriceTmp[1] := ItemInfoExtendCopy;
                    ItemPriceTmp[1].INSERT;
                    CalcOffercLine(ItemPriceTmp[1], 'VIP', TenderCode);
                    ItemPriceTmp[1].MODIFY;

                    IF ItemInfoExtTmp.Description = '' THEN BEGIN
                        ItemInfoExtTmp.Description := Item.Description;
                        ItemInfoExtTmp.MODIFY;
                    END;
                    IF ItemPriceTmp[1].Description = '' THEN BEGIN
                        ItemPriceTmp[1].Description := ItemInfoExtTmp.Description;
                        ItemPriceTmp[1].MODIFY;
                    END;
                    IF ItemPriceTmp[2].Description = '' THEN BEGIN
                        ItemPriceTmp[2].Description := ItemInfoExtTmp.Description;
                        ItemPriceTmp[2].MODIFY;
                    END;
                END;
                //Disc
                IF UMExists THEN
                    IF BlockFromHierarchy AND NOT ItemInfoExtTmp."Blocked Ecommerce" THEN BEGIN
                        ItemInfoExtTmp."Blocked Ecommerce" := TRUE;
                        ItemInfoExtTmp.Reason := TableCaptionBlock;
                        ItemInfoExtTmp.MODIFY;
                    END;
                IF UMExists THEN BEGIN
                    IF ItemPriceTmp[1]."Blocked Ecommerce" <> ItemInfoExtTmp."Blocked Ecommerce" THEN BEGIN
                        ItemPriceTmp[1]."Blocked Ecommerce" := ItemInfoExtTmp."Blocked Ecommerce";
                        ItemPriceTmp[1].Reason := ItemInfoExtTmp.Reason;
                        ItemPriceTmp[1].MODIFY;
                    END;
                    IF ItemPriceTmp[2]."Blocked Ecommerce" <> ItemInfoExtTmp."Blocked Ecommerce" THEN BEGIN
                        ItemPriceTmp[2]."Blocked Ecommerce" := ItemInfoExtTmp."Blocked Ecommerce";
                        ItemPriceTmp[2].Reason := ItemInfoExtTmp.Reason;
                        ItemPriceTmp[2].MODIFY;
                    END;
                END;
            UNTIL ItemInfoExtTmp.NEXT = 0;

        ItemInfoExtTmp.RESET;
        ItemInfoExtTmp.SETRANGE(ItemInfoExtTmp."Line No.", 0);
        ItemInfoExtTmp.SETRANGE(ItemInfoExtTmp."No.", pItemTest);
        IF ItemInfoExtTmp.FIND('-') THEN
            REPEAT
                IF ItemInfoExtend.GET(ItemInfoExtTmp."Entry Type", ItemInfoExtTmp."Sub Type", ItemInfoExtTmp."No."
                  , ItemInfoExtTmp."Unit of Measure", ItemInfoExtTmp."Line No.") THEN BEGIN
                    IF RecordTmpChanged(ItemInfoExtTmp, ItemInfoExtend) THEN BEGIN
                        ItemInfoExtTmp."Image Link" := ItemInfoExtend."Image Link";
                        ItemInfoExtend.TRANSFERFIELDS(ItemInfoExtTmp);
                        ItemInfoExtend.MODIFY(TRUE);
                    END;
                    ItemInfoExt2.SETRANGE(ItemInfoExt2."Entry Type", ItemInfoExtend."Entry Type");
                    ItemInfoExt2.SETRANGE(ItemInfoExt2."Sub Type", ItemInfoExtend."Sub Type");
                    ItemInfoExt2.SETRANGE(ItemInfoExt2."No.", ItemInfoExtend."No.");
                    ItemInfoExt2.SETRANGE(ItemInfoExt2."Unit of Measure", ItemInfoExtend."Unit of Measure");
                    ItemInfoExt2.SETRANGE(ItemInfoExt2."Line No.", ItemInfoExtend."Line No." + 1, ItemInfoExtend."Line No." + 3);
                    IF ItemInfoExt2.FIND('-') THEN
                        REPEAT
                            IF ItemInfoExt2."Price Default" <> ItemInfoExtend."Price Default" THEN BEGIN
                                ItemInfoExt2."Price Default" := ItemInfoExtend."Price Default";
                                ItemInfoExt2."Price Inc. Disc. Default" := ItemInfoExtend."Price Default" - ROUND((ItemInfoExt2."Discount Default" / 100) * ItemInfoExtend."Price Default", 0.01);
                                ItemInfoExt2.MODIFY(TRUE);
                            END;
                        UNTIL ItemInfoExt2.NEXT = 0;
                END;
            UNTIL ItemInfoExtTmp.NEXT = 0;

        ItemPriceTmp[2].RESET;
        ItemPriceTmp[2].SETRANGE(ItemPriceTmp[2]."Line No.", 0);
        IF ItemPriceTmp[2].FIND('-') THEN
            REPEAT
                IF ItemInfoExtend.GET(ItemPriceTmp[2]."Entry Type", ItemPriceTmp[2]."Sub Type", ItemPriceTmp[2]."No."
                  , ItemPriceTmp[2]."Unit of Measure", ItemPriceTmp[2]."Line No.") THEN BEGIN
                    IF RecordTmpChanged(ItemPriceTmp[2], ItemInfoExtend) THEN BEGIN
                        ItemInfoExtend.TRANSFERFIELDS(ItemPriceTmp[2]);
                        ItemInfoExtend.MODIFY(TRUE);
                    END;
                    ItemInfoExt2.SETRANGE(ItemInfoExt2."Entry Type", ItemInfoExtend."Entry Type");
                    ItemInfoExt2.SETRANGE(ItemInfoExt2."Sub Type", ItemInfoExtend."Sub Type");
                    ItemInfoExt2.SETRANGE(ItemInfoExt2."No.", ItemInfoExtend."No.");
                    ItemInfoExt2.SETRANGE(ItemInfoExt2."Unit of Measure", ItemInfoExtend."Unit of Measure");
                    ItemInfoExt2.SETRANGE(ItemInfoExt2."Line No.", ItemInfoExtend."Line No." + 1, ItemInfoExtend."Line No." + 3);
                    IF ItemInfoExt2.FIND('-') THEN
                        REPEAT
                            IF ItemInfoExt2."Price Default" <> ItemInfoExtend."Price Default" THEN BEGIN
                                ItemInfoExt2."Price Default" := ItemInfoExtend."Price Default";
                                ItemInfoExt2."Price Inc. Disc. Default" := ItemInfoExtend."Price Default" - ROUND((ItemInfoExt2."Discount Default" / 100) * ItemInfoExtend."Price Default", 0.01);
                                ItemInfoExt2.MODIFY(TRUE);
                            END;
                        UNTIL ItemInfoExt2.NEXT = 0;
                END;
            UNTIL ItemPriceTmp[2].NEXT = 0;

        ItemPriceTmp[1].RESET;
        ItemPriceTmp[1].SETRANGE(ItemPriceTmp[1]."Line No.", 200);
        IF ItemPriceTmp[1].FIND('-') THEN
            REPEAT
                IF ItemInfoExtend.GET(ItemPriceTmp[1]."Entry Type", ItemPriceTmp[1]."Sub Type", ItemPriceTmp[1]."No."
                  , ItemPriceTmp[1]."Unit of Measure", ItemPriceTmp[1]."Line No.") THEN BEGIN
                    IF RecordTmpChanged(ItemPriceTmp[1], ItemInfoExtend) THEN BEGIN
                        ItemInfoExtend.TRANSFERFIELDS(ItemPriceTmp[1]);
                        ItemInfoExtend.MODIFY(TRUE);
                    END;
                    ItemInfoExt2.SETRANGE(ItemInfoExt2."Entry Type", ItemInfoExtend."Entry Type");
                    ItemInfoExt2.SETRANGE(ItemInfoExt2."Sub Type", ItemInfoExtend."Sub Type");
                    ItemInfoExt2.SETRANGE(ItemInfoExt2."No.", ItemInfoExtend."No.");
                    ItemInfoExt2.SETRANGE(ItemInfoExt2."Unit of Measure", ItemInfoExtend."Unit of Measure");
                    ItemInfoExt2.SETRANGE(ItemInfoExt2."Line No.", ItemInfoExtend."Line No." + 1, ItemInfoExtend."Line No." + 3);
                    IF ItemInfoExt2.FIND('-') THEN
                        REPEAT
                            IF ItemInfoExt2."Price Default" <> ItemInfoExtend."Price Default" THEN BEGIN
                                ItemInfoExt2."Price Default" := ItemInfoExtend."Price Default";
                                ItemInfoExt2."Price Inc. Disc. Default" := ItemInfoExtend."Price Default" - ROUND((ItemInfoExt2."Discount Default" / 100) * ItemInfoExtend."Price Default", 0.01);
                                ItemInfoExt2.MODIFY(TRUE);
                            END;
                        UNTIL ItemInfoExt2.NEXT = 0;
                END;
            UNTIL ItemPriceTmp[1].NEXT = 0;

    end;

    [Obsolete]
    procedure UpdateStaticLimitEcommSql() Msg: Text
    var
        SQLRead: Codeunit "FSN SQL Data Reader";
        SqlDataReaderNET: DotNet SqlDataReader;
        ParameterWS: Record "FSN Parameter";
        ItemUMPurch_l: Record "Item Unit of Measure";
        DistribLocCode: Code[10];
        "Query": Text;
        ItemCode: Text[20];
        QueryTxt: Text;
        Index: Integer;
        j: Integer;
        Sucessffull: Boolean;
        lText001: Label 'Conection Error DB';
        lText002: Label 'Cant be suggest items';
    begin
        ItemInfoExtend.RESET;
        ItemInfoExtend.SETRANGE(ItemInfoExtend."Entry Type", ItemInfoExtend."Entry Type"::EcommerceLimit);
        ItemInfoExtend.SETRANGE(ItemInfoExtend."Sub Type", ItemInfoExtend."Sub Type"::ItemSetting);
        ItemInfoExtend.SETRANGE(ItemInfoExtend."Source Type", ItemInfoExtend."Source Type"::AutomaticStatic);
        ItemInfoExtend.SETRANGE(ItemInfoExtend."Starting Date", TODAY);
        ItemInfoExtend.SETRANGE(ItemInfoExtend."Line No.", 10000);
        IF ItemInfoExtend.FIND('-') THEN
            EXIT;

        UpdateDTCommand(TRUE);
        COMMIT;
        IF NOT ParameterWS.GET('ECOM', 'TOP20SQL') AND ParameterWS.Activo THEN
            EXIT;
        IF (ParameterWS.Valor = '') OR (ParameterWS."Distribution Location Ext." = '') THEN
            EXIT;

        Query := 'EXEC ' + ParameterWS.Valor;
        DistribLocCode := ParameterWS."Distribution Location Ext.";

        SQLRead.ClearParams();
        SQLRead.SetDistributionLocation(DistribLocCode);
        SQLRead.SetQuery(Query);
        SQLRead.SetAction('OPEN');
        COMMIT;
        IF SQLRead.RUN THEN;
        IF NOT SQLRead.IsConnect THEN
            EXIT;

        SQLRead.SetAction('POST');
        COMMIT;
        IF SQLRead.RUN THEN;

        ItemInfoExtTmp.RESET;
        ItemInfoExtTmp.DELETEALL;

        CLEAR(Index);
        SQLRead.GetDataReader(SqlDataReaderNET);
        IF NOT ISNULL(SqlDataReaderNET) THEN
            WHILE SqlDataReaderNET.Read() AND (Index < 40) DO BEGIN
                Index += 1;
                ItemCode := SqlDataReaderNET.Item('Element No_');
                ItemInfoExtTmp.INIT();
                ItemInfoExtTmp."Entry Type" := ItemInfoExtTmp."Entry Type"::EcommerceLimit;
                ItemInfoExtTmp."No." := ItemCode;
                IF ItemInfoExtTmp.INSERT THEN;
            END;

        SQLRead.SetAction('CLOSE');
        COMMIT;
        IF SQLRead.RUN THEN;
        SQLRead.ClearParams();

        ItemInfoExtTmp.RESET;
        IF ItemInfoExtTmp.FIND('-') THEN
            REPEAT
                ItemUnitofMeasure.RESET;
                ItemUnitofMeasure.SETRANGE(ItemUnitofMeasure."Item No.", ItemInfoExtTmp."No.");
                IF Item.GET(ItemInfoExtTmp."No.") THEN
                    IF ItemUnitofMeasure.FIND('-') THEN
                        REPEAT
                            j := 1;
                            IF ItemUMPurch_l.GET(ItemUnitofMeasure."Item No.", Item."Purch. Unit of Measure") THEN
                                j := ItemUMPurch_l."Qty. per Unit of Measure";

                            CLEAR(ItemInfoExtend);
                            ItemInfoExtend.INIT;
                            ItemInfoExtend."Entry Type" := ItemInfoExtend."Entry Type"::EcommerceLimit;
                            ItemInfoExtend."Sub Type" := ItemInfoExtend."Sub Type"::ItemSetting;
                            ItemInfoExtend."Item Type" := 0;
                            ItemInfoExtend.VALIDATE("No.", ItemUnitofMeasure."Item No.");
                            ItemInfoExtend."Unit of Measure" := ItemUnitofMeasure.Code;
                            ItemInfoExtend."Line No." := 10000;
                            IF j = ItemUnitofMeasure."Qty. per Unit of Measure" THEN
                                ItemInfoExtend.Quantity := 400
                            ELSE
                                ItemInfoExtend.Quantity := 400 * j;
                            ItemInfoExtend."Blocked Ecommerce" := FALSE;
                            ItemInfoExtend."Starting Date" := TODAY;
                            ItemInfoExtend."Source Type" := ItemInfoExtend."Source Type"::AutomaticStatic;
                            IF NOT ItemInfoExtend.INSERT(TRUE) THEN
                                ItemInfoExtend.MODIFY(TRUE);
                        UNTIL ItemUnitofMeasure.NEXT = 0;
            UNTIL ItemInfoExtTmp.NEXT = 0;

        UpdateDTCommand(FALSE);
    end;

    procedure UpdateDTCommand(IsStart: Boolean)
    var
        ItemInfoCommand: Record "FSN Item Info. Extend";
    begin
        IF GlobalCommand = '' THEN
            EXIT;
        ItemInfoCommand.SETRANGE(ItemInfoCommand."Entry Type", ItemInfoCommand."Entry Type"::Parameters);
        ItemInfoCommand.SETRANGE(ItemInfoCommand."Sub Type", ItemInfoCommand."Sub Type"::Information);
        ItemInfoCommand.SETRANGE(ItemInfoCommand."No.", GlobalCommand);
        IF NOT ItemInfoCommand.FIND('-') THEN BEGIN
            ItemInfoCommand.INIT;
            ItemInfoCommand."Entry Type" := ItemInfoCommand."Entry Type"::Parameters;
            ItemInfoCommand."Sub Type" := ItemInfoCommand."Sub Type"::Information;
            ItemInfoCommand."No." := GlobalCommand;
            ItemInfoCommand."Unit of Measure" := '';
            ItemInfoCommand."Line No." := 0;
            ItemInfoCommand.INSERT;
        END;
        IF IsStart THEN BEGIN
            ItemInfoCommand."Starting Date" := TODAY;
            ItemInfoCommand."Start Time" := TIME;
        END ELSE BEGIN
            ItemInfoCommand."Ending Date" := TODAY;
            ItemInfoCommand."End Time" := TIME;
        END;
        ItemInfoCommand.MODIFY(TRUE);
    end;

    procedure ValidateDateTimeRecord(Rec: Record "FSN Item Info. Extend"): Boolean
    var
        OkDateTime: Boolean;
    begin
        IF ((Rec."Starting Date" <= GlobalDate) OR (Rec."Starting Date" = 0D)) THEN
            IF (Rec."Start Time" = 0T) OR
              (Rec."Start Time" <= GlobalTime) AND (Rec."Starting Date" = GlobalDate) THEN
                IF ((Rec."Ending Date" >= GlobalDate) OR (Rec."Ending Date" = 0D)) THEN
                    IF (Rec."End Time" = 0T) OR (Rec."End Time" >= GlobalTime) THEN
                        EXIT(TRUE);
        EXIT(FALSE);
    end;

    procedure ValidateExpireDT(Rec: Record "FSN Item Info. Extend"): Boolean
    begin
        IF ((Rec."Ending Date" <> 0D) AND (Rec."Ending Date" < GlobalDate)) THEN
            EXIT(TRUE);

        IF (Rec."Ending Date" = GlobalDate) AND (Rec."End Time" < GlobalTime) AND (Rec."End Time" <> 0T) THEN
            EXIT(TRUE);

        EXIT(FALSE);
    end;

    procedure UpdateHugoItem()
    var
        ParameterWS: Record "FSN Parameter";
        Parameters: DotNet Dictionary_Of_T_U;
        HttpResponseMessage: DotNet HttpResponseMessage;
        ODATA: Codeunit "FSN OData Conexion";
        HierarchyActiveTMP: Record "FSN Item Info. Extend" temporary;
        TaxonomiesTMP: Record "FSN Item Info. Extend" temporary;
        ItemLinkPriceBaseTmp: Record "FSN Item Info. Extend" temporary;
        LineNextTable: Record "FSN Item Info. Extend";
        FileSystem: DotNet StreamWriter;
        LSJson: Codeunit "FSN Windows Forms NET";
        jValueArr: array[100] of Text[1024];
        jObject: DotNet JObject;
        jObjectItem: DotNet JObject;
        jObjectImg: DotNet JObject;
        jObjectParent: DotNet JObject;
        JWriter: DotNet JsonWriter;
        i: Integer;
        DataExists: Boolean;
        Sucess: Boolean;
        extra_info: Text[100];
        extraInfoInPriceBase: Boolean;
        result: Text;
        Counter: Integer;
        Taxonomy: Text;
        IsNewHugo: Boolean;
        lTxt1: Label 'Precio regular: %1';
        lTxt2: Label 'Producto en oferta';
    begin
        SetRUNMode(GlobalCommand);
        UpdateDTCommand(TRUE);
        COMMIT;

        IF NOT ParameterWS.GET('HUGOAPP', 'ITEM') THEN
            EXIT;

        GlobalParametersSetup.SETRANGE(GlobalParametersSetup."No.", 'HUGOPATH');
        if GlobalParametersSetup.Find('-') and (GlobalParametersSetup."Free Text" <> '') then
            GlobalHugoPath := GlobalParametersSetup."Free Text"
        else
            GlobalHugoPath := StaticHugoPath;

        Parameters := Parameters.Dictionary();
        Parameters.Add('baseurl', ParameterWS."Web Uri");
        Parameters.Add('restmethod', 'POST');
        Parameters.Add('path', ParameterWS."Web Uri");//Equal
        Parameters.Add('accept', ParameterWS."Value Text 1");
        Parameters.Add('Bearer', ParameterWS.Valor);
        Parameters.Add('httpcontent', 'OK');
        ODATA.InitRequestGlobals('', ParameterWS."Value Text 1", '', ParameterWS.Valor, '', '');

        HierarchyActiveTMP.RESET;
        HierarchyActiveTMP.DELETEALL;
        TaxonomiesTMP.RESET;
        TaxonomiesTMP.DELETEALL;
        ItemInfoExtTmp.RESET;
        ItemInfoExtTmp.DELETEALL;
        ItemLinkPriceBaseTmp.RESET;
        ItemLinkPriceBaseTmp.DELETEALL;
        CLEAR(HierarchyActiveTMP);
        CLEAR(TaxonomiesTMP);
        CLEAR(ItemInfoExtTmp);
        CLEAR(ItemLinkPriceBaseTmp);
        CLEAR(Counter);

        ItemInfoExtend.RESET;
        ItemInfoExtend.SETCURRENTKEY("Entry Type", "Sub Type", "No.", "Unit of Measure", "Line No.");
        ItemInfoExtend.SETRANGE(ItemInfoExtend."Entry Type", ItemInfoExtend."Entry Type"::EcommerceHierarchy);
        ItemInfoExtend.SETRANGE(ItemInfoExtend."Sub Type", ItemInfoExtend."Sub Type"::ItemSetting);
        ItemInfoExtend.SETRANGE(ItemInfoExtend."Item Type", ItemInfoExtend."Item Type"::ProductGroup);
        ItemInfoExtend.SETRANGE(ItemInfoExtend."Unit of Measure", 'HUGO');//Integration
        IF ItemInfoExtend.FIND('-') THEN
            REPEAT
                IF ValidateDateTimeRecord(ItemInfoExtend) THEN BEGIN
                    HierarchyActiveTMP.INIT;
                    HierarchyActiveTMP := ItemInfoExtend;
                    HierarchyActiveTMP.INSERT;

                    TaxonomiesTMP.INIT;
                    TaxonomiesTMP := ItemInfoExtend;
                    TaxonomiesTMP.INSERT;

                END;
            UNTIL ItemInfoExtend.NEXT = 0;
        COMMIT;

        ItemInfoExtend.SETRANGE(ItemInfoExtend."No.", '30000000');
        IF ItemInfoExtend.FIND('-') THEN BEGIN

            ItemInfoExt2.RESET;
            ItemInfoExt2.SETRANGE(ItemInfoExt2."Entry Type", ItemInfoExt2."Entry Type"::EcommerceHierarchy);
            ItemInfoExt2.SETRANGE(ItemInfoExt2."Sub Type", ItemInfoExt2."Sub Type"::ItemLink);
            ItemInfoExt2.SETRANGE(ItemInfoExt2."No.", '30000000');
            ItemInfoExt2.SETRANGE(ItemInfoExt2.ID, 'HUGO');
            IF ItemInfoExt2.FIND('-') THEN
                REPEAT
                    IF ValidateDateTimeRecord(ItemInfoExt2) THEN BEGIN
                        ItemLinkPriceBaseTmp.INIT;
                        ItemLinkPriceBaseTmp := ItemInfoExt2;
                        IF ItemInfoExtend.Reason <> '' THEN
                            ItemLinkPriceBaseTmp.Reason := ItemInfoExtend.Reason;
                        ItemLinkPriceBaseTmp.INSERT;
                    END;
                UNTIL ItemInfoExt2.NEXT = 0;

        END;
        ItemInfoExt2.RESET;

        LineNextTable.RESET;
        LineNextTable.SETCURRENTKEY(Sort);
        LineNextTable.SETRANGE(LineNextTable."Entry Type", LineNextTable."Entry Type"::EcommercePrices);
        LineNextTable.SETRANGE(LineNextTable."Sub Type", LineNextTable."Sub Type"::ItemSetting);
        LineNextTable.SETRANGE(LineNextTable.ID, 'HUGO');
        IF LineNextTable.FINDLAST THEN
            i := LineNextTable.Sort + 1
        ELSE
            i := 1;

        CLEAR(extra_info);
        LineNextTable.RESET;
        LineNextTable.SETRANGE(LineNextTable."Entry Type", LineNextTable."Entry Type"::Parameters);
        LineNextTable.SETRANGE(LineNextTable."Sub Type", LineNextTable."Sub Type"::ItemSetting);
        LineNextTable.SETFILTER(LineNextTable."Free Text", '<>%1', '');
        LineNextTable.SETRANGE(LineNextTable."No.", 'EXTRA_INFO');
        LineNextTable.SETRANGE(LineNextTable."Unit of Measure", 'HUGO');
        IF LineNextTable.FINDLAST THEN
            extra_info := LineNextTable."Free Text";

        HierarchyActiveTMP.RESET;
        IF HierarchyActiveTMP.FIND('-') THEN
            REPEAT
                Item.RESET;
                Item.SETRANGE(Item."LSC Retail Product Code", HierarchyActiveTMP."No.");
                IF Item.FIND('-') THEN
                    REPEAT

                        ItemUnitofMeasure.RESET;
                        ItemUnitofMeasure.SETRANGE(ItemUnitofMeasure."Item No.", Item."No.");
                        IF ItemUnitofMeasure.FIND('-') THEN
                            REPEAT
                                IF ItemInfoExtendCopy.GET(4, 1, ItemUnitofMeasure."Item No.", ItemUnitofMeasure.Code, 0) THEN BEGIN
                                    GetEcomPriceTmp1FromEcomItem(ItemInfoExtendCopy, 100, ItemInfoExtTmp, IsNewHugo, 'HUGO');
                                    CalcOffercLine(ItemInfoExtTmp, 'HUGO', GetIDParameter('EMPRETAIL', '20'));
                                    UpdateChanges(ItemInfoExtTmp);//Changes tmp
                                    IF ItemInfoExtTmp.Description = '' THEN
                                        ItemInfoExtTmp.Description := Item.Description;

                                    IF ItemInfoExtTmp."Require Medical Document" AND NOT ItemInfoExtTmp."Blocked Ecommerce" THEN BEGIN
                                        ItemInfoExtTmp."Blocked Ecommerce" := TRUE;
                                        ItemInfoExtTmp.Reason := ItemInfoExtTmp.FIELDCAPTION("Require Medical Document");
                                    END;
                                    IF NOT ItemInfoExtTmp."Blocked Ecommerce" AND (ItemInfoExtTmp."Price Inc. Disc. Default" <= 0) THEN BEGIN
                                        ItemInfoExtTmp."Blocked Ecommerce" := TRUE;
                                        ItemInfoExtTmp.Reason := ItemInfoExtTmp.FIELDCAPTION(ItemInfoExtTmp."Price Inc. Disc. Default");
                                    END;

                                    IF ItemInfoExtendCopy.GET(5, 1, ItemInfoExtTmp."No.", ItemInfoExtTmp."Unit of Measure", 100) THEN
                                        ItemInfoExtTmp.Sort := ItemInfoExtendCopy.Sort;

                                    IF ItemInfoExtTmp.Sort = 0 THEN BEGIN
                                        ItemInfoExtTmp.Sort := i;
                                        i += 1;
                                    END;
                                    ItemInfoExtTmp.MODIFY;
                                END;
                            UNTIL ItemUnitofMeasure.NEXT = 0;
                    UNTIL Item.NEXT = 0;
            UNTIL HierarchyActiveTMP.NEXT = 0;
        CLEAR(i);

        ItemInfoExtend.RESET;
        ItemInfoExtend.SETRANGE(ItemInfoExtend."Entry Type", ItemInfoExtend."Entry Type"::EcommercePrices);
        ItemInfoExtend.SETRANGE(ItemInfoExtend."Item Type", ItemInfoExtend."Item Type"::Item);
        ItemInfoExtend.SETRANGE(ItemInfoExtend."Line No.", 100);
        IF ItemInfoExtend.FIND('-') THEN
            REPEAT
                IF NOT ItemInfoExtTmp.GET(5, 1, ItemInfoExtend."No.", ItemInfoExtend."Unit of Measure", 100) THEN BEGIN
                    IF NOT ItemInfoExtend."Blocked Ecommerce" THEN BEGIN
                        ItemInfoExtend."Blocked Ecommerce" := TRUE;
                        ItemInfoExtend.Reason :=
                          COPYSTR(ItemInfoExtend.FIELDCAPTION("Hierarchy Parent Code") + '-' + ItemInfoExtend.FIELDCAPTION("Blocked Ecommerce"), 1, 50);
                        ItemInfoExtend.MODIFY(TRUE);
                    END;
                END;
            UNTIL ItemInfoExtend.NEXT = 0;

        COMMIT;
        ItemInfoExtTmp.RESET;
        IF ItemInfoExtTmp.FIND('-') THEN
            REPEAT
                IF NOT ItemInfoExtendCopy.GET(5, 1, ItemInfoExtTmp."No.", ItemInfoExtTmp."Unit of Measure", 100) THEN BEGIN
                    ItemInfoExtendCopy.INIT();
                    ItemInfoExtendCopy := ItemInfoExtTmp;
                    ItemInfoExtendCopy.INSERT(TRUE);
                END ELSE BEGIN
                    IF (ItemInfoExtendCopy."Starting Date" <> 0D) OR (ItemInfoExtendCopy."Ending Date" <> 0D) THEN BEGIN
                        IF ValidateExpireDT(ItemInfoExtendCopy) THEN
                            IF RecordTmpChanged(ItemInfoExtTmp, ItemInfoExtendCopy) THEN BEGIN
                                ItemInfoExtendCopy.TRANSFERFIELDS(ItemInfoExtTmp);
                                ItemInfoExtendCopy.MODIFY(TRUE);
                            END;
                    END ELSE BEGIN
                        IF RecordTmpChanged(ItemInfoExtTmp, ItemInfoExtendCopy) THEN BEGIN
                            ItemInfoExtendCopy.TRANSFERFIELDS(ItemInfoExtTmp);
                            ItemInfoExtendCopy.MODIFY(TRUE);
                        END;
                    END;
                END;
            UNTIL ItemInfoExtTmp.NEXT = 0;


        ItemInfoExtTmp.RESET;
        ItemInfoExtTmp.DELETEALL;
        CLEAR(ItemInfoExtTmp);
        COMMIT;
        CLEAR(RequestTxt);
        CLEAR(DataExists);

        jObjectParent := jObjectParent.JObject();
        JWriter := jObjectParent.CreateWriter();
        JWriter.WritePropertyName('Object');
        JWriter.WriteStartArray();

        ItemInfoExtend.RESET;
        ItemInfoExtend.SETCURRENTKEY("Entry Type", "Sub Type", "No.", "Unit of Measure", "Line No.");
        ItemInfoExtend.SETRANGE(ItemInfoExtend."Entry Type", ItemInfoExtend."Entry Type"::EcommercePrices);
        ItemInfoExtend.SETRANGE(ItemInfoExtend."Sub Type", ItemInfoExtend."Sub Type"::ItemSetting);
        ItemInfoExtend.SETRANGE(ItemInfoExtend.ID, 'HUGO');
        ItemInfoExtend.SETRANGE(ItemInfoExtend."Blocked Ecommerce", FALSE);
        ItemInfoExtend.SETRANGE(ItemInfoExtend."Line No.", 100);
        ItemInfoExtend.SETFILTER(ItemInfoExtend."Price Inc. Disc. Default", '>0');
        IF ItemInfoExtend.FIND('-') THEN
            REPEAT
                HierarchyActiveTMP.RESET;
                HierarchyActiveTMP.SETRANGE(HierarchyActiveTMP."No.", ItemInfoExtend."Hierarchy Parent Code");
                IF HierarchyActiveTMP.FIND('-') AND (HierarchyActiveTMP."Free Text" <> '') THEN BEGIN //HierarchyActiveTMP."Free Text" is code taxonomy
                    jObjectImg := jObjectImg.JObject();
                    jObjectItem := jObjectItem.JObject();
                    LSJson.WriterPropertyObject(jObjectItem, 'sku', 0, (ItemInfoExtend."No." + ItemInfoExtend."Unit of Measure"), 0, 0, 0T, 0DT, 0D, FALSE);
                    LSJson.WriterPropertyObject(jObjectItem, 'sort', 1, '', ItemInfoExtend.Sort, 0, 0T, 0DT, 0D, FALSE);
                    LSJson.WriterPropertyObject(jObjectItem, 'name', 0, DELCHR(ItemInfoExtend.Description, '=', '"<>'), 0, 0, 0T, 0DT, 0D, FALSE);
                    LSJson.WriterPropertyObject(jObjectItem, 'description', 0, GetItemIngredient(ItemInfoExtend."No."), 0, 0, 0T, 0DT, 0D, FALSE);

                    extraInfoInPriceBase := FALSE;
                    ItemLinkPriceBaseTmp.RESET;
                    ItemLinkPriceBaseTmp.SETRANGE(ItemLinkPriceBaseTmp."Unit of Measure", ItemInfoExtend."No.");
                    IF ItemLinkPriceBaseTmp.FIND('-') THEN BEGIN
                        LSJson.WriterPropertyObject(jObjectItem, 'price', 2, '', 0, ItemInfoExtend."Price Default", 0T, 0DT, 0D, FALSE);

                        IF ItemLinkPriceBaseTmp.Reason <> '' THEN
                            LSJson.WriterPropertyObject(jObjectItem, 'extra_info', 0
                              , STRSUBSTNO(ItemLinkPriceBaseTmp.Reason, FORMAT(ItemInfoExtend."Price Default", 0, '<Precision,2:2><Standard Format,2>'))
                              , 0, 0, 0T, 0DT, 0D, FALSE)
                        ELSE
                            LSJson.WriterPropertyObject(jObjectItem, 'extra_info', 0
                              , lTxt2
                              , 0, 0, 0T, 0DT, 0D, FALSE);

                        extraInfoInPriceBase := TRUE;
                    END ELSE
                        LSJson.WriterPropertyObject(jObjectItem, 'price', 2, '', 0, ItemInfoExtend."Price Inc. Disc. Default", 0T, 0DT, 0D, FALSE);


                    IF NOT extraInfoInPriceBase THEN
                        IF (extra_info <> '') THEN BEGIN
                            IF ItemInfoExtend."Price Default" > ItemInfoExtend."Price Inc. Disc. Default" THEN
                                LSJson.WriterPropertyObject(jObjectItem, 'extra_info', 0
                                  , STRSUBSTNO(extra_info, FORMAT(ItemInfoExtend."Price Default", 0, '<Precision,2:2><Standard Format,2>')
                                                    , FORMAT(ItemInfoExtend."Discount Default", 0, '<Precision,2:2><Standard Format,2>')
                                                    , FORMAT(ABS(ItemInfoExtend."Price Inc. Disc. Default" - ItemInfoExtend."Price Default"), 0, '<Precision,2:2><Standard Format,2>'))
                                  , 0, 0, 0T, 0DT, 0D, FALSE)
                            ELSE
                                LSJson.WriterPropertyObject(jObjectItem, 'extra_info', 0
                                  , STRSUBSTNO(lTxt1, FORMAT(ItemInfoExtend."Price Default", 0, '<Precision,2:2><Standard Format,2>'))
                                  , 0, 0, 0T, 0DT, 0D, FALSE);
                        END ELSE
                            LSJson.WriterPropertyObject(jObjectItem, 'extra_info', 0, GetItemInfoExtend(ItemInfoExtend."No.", ''), 0, 0, 0T, 0DT, 0D, FALSE);

                    jValueArr[1] := '';
                    IF ItemInfoExtend."Image Link" <> '' THEN BEGIN
                        LSJson.WriterPropertyObject(jObjectImg, 'format', 0, 'url', 0, 0, 0T, 0DT, 0D, FALSE);
                        jValueArr[1] := DELCHR(ItemInfoExtend."Image Link", '=', '"<>');
                        LSJson.WriterPropertyArrayObject(jObjectImg, 'list', jValueArr, 1, 0);
                        jValueArr[1] := jObjectImg.ToString();
                        LSJson.WriterPropertyArrayObject(jObjectItem, 'images', jValueArr, 1, 6);
                    END;

                    jValueArr[1] := HierarchyActiveTMP."Free Text";
                    i := 1;

                    ItemInfoExt2.RESET;
                    ItemInfoExt2.SETRANGE(ItemInfoExt2."Entry Type", ItemInfoExt2."Entry Type"::EcommerceHierarchy);
                    ItemInfoExt2.SETRANGE(ItemInfoExt2."Sub Type", ItemInfoExt2."Sub Type"::ItemLink);
                    ItemInfoExt2.SETRANGE(ItemInfoExt2."Unit of Measure", ItemInfoExtend."No.");
                    ItemInfoExt2.SETRANGE(ItemInfoExt2.ID, 'HUGO');
                    IF ItemInfoExt2.FIND('-') THEN
                        REPEAT
                            IF ValidateDateTimeRecord(ItemInfoExt2) THEN BEGIN

                                TaxonomiesTMP.RESET;
                                TaxonomiesTMP.SETRANGE(TaxonomiesTMP."No.", ItemInfoExt2."No.");
                                TaxonomiesTMP.SETRANGE(TaxonomiesTMP."Blocked Ecommerce", FALSE);
                                IF TaxonomiesTMP.FIND('-') AND (TaxonomiesTMP."Free Text" <> '') THEN BEGIN
                                    i += 1;
                                    jValueArr[i] := TaxonomiesTMP."Free Text";
                                END;
                            END;
                        UNTIL ItemInfoExt2.NEXT = 0;

                    LSJson.WriterPropertyArrayObject(jObjectItem, 'taxonomies', jValueArr, i, 0);
                    JWriter.WriteRaw(jObjectItem.ToString());

                    ItemInfoExtTmp.INIT;
                    ItemInfoExtTmp := ItemInfoExtend;
                    ItemInfoExtTmp.INSERT;
                    DataExists := TRUE;
                END;
            UNTIL ItemInfoExtend.NEXT = 0;

        JWriter.WriteEndArray();
        JWriter.Close();

        IF NOT ISNULL(jObjectParent) THEN
            jObjectParent := jObjectParent.SelectToken('Object');

        RequestTxt := jObjectParent.ToString();
        IF (RequestTxt <> '') AND DataExists THEN BEGIN
            FileSystem := FileSystem.StreamWriter(GlobalHugoPath + 'HUGOITEM.xml');
            FileSystem.Write(RequestTxt);
            FileSystem.Close();
            ODATA.SetBodyGlobal(RequestTxt);
            ODATA.CallRESTWebService(Parameters, HttpResponseMessage);
            result := HttpResponseMessage.Content.ReadAsStringAsync.Result;

            FileSystem := FileSystem.StreamWriter(GlobalHugoPath + 'HUGOITEM_R.xml');
            FileSystem.Write(result);
            FileSystem.Close();
            IF HttpResponseMessage.IsSuccessStatusCode() THEN BEGIN
                IF result = '[]' THEN
                    Sucess := TRUE;

                IF Sucess THEN BEGIN
                    ItemInfoExtTmp.RESET;
                    IF ItemInfoExtTmp.FIND('-') THEN
                        REPEAT
                            IF ItemInfoExtend.GET(ItemInfoExtTmp."Entry Type", ItemInfoExtTmp."Sub Type"
                              , ItemInfoExtTmp."No.", ItemInfoExtTmp."Unit of Measure", ItemInfoExtTmp."Line No.") THEN BEGIN
                                IF ItemInfoExtend."Image Link" <> '' THEN BEGIN
                                    ItemInfoExtend."Image Link" := '';
                                    ItemInfoExtend.MODIFY(TRUE);
                                END;
                            END;
                        UNTIL ItemInfoExtTmp.NEXT = 0;
                END;
            END;
        END;

        UpdateDTCommand(FALSE);

    end;

    procedure UpdateHugoReset()
    var
        ParameterWS: Record "FSN Parameter";
        Parameters: DotNet Dictionary_Of_T_U;
        HttpResponseMessage: DotNet HttpResponseMessage;
        result: Text;
        ODATA: Codeunit "FSN OData Conexion";
        Counter: Integer;
        Taxonomy: Text;
        HierarchyActiveTMP: Record "FSN Item Info. Extend" temporary;
        TaxonomiesTMP: Record "FSN Item Info. Extend" temporary;
        IsNewHugo: Boolean;
        FileSystem: DotNet StreamWriter;
        LSJson: Codeunit "FSN Windows Forms NET";
        jValueArr: array[100] of Text[1024];
        jObject: DotNet JObject;
        jObjectItem: DotNet JObject;
        jObjectImg: DotNet JObject;
        jObjectParent: DotNet JObject;
        JWriter: DotNet JsonWriter;
        i: Integer;
        DataExists: Boolean;
    begin
        SetRUNMode(GlobalCommand);
        UpdateDTCommand(TRUE);
        COMMIT;

        IF NOT ParameterWS.GET('HUGOAPP', 'ITEMRESET') THEN
            EXIT;
        GlobalParametersSetup.SETRANGE(GlobalParametersSetup."No.", 'HUGOPATH');
        if GlobalParametersSetup.Find('-') and (GlobalParametersSetup."Free Text" <> '') then
            GlobalHugoPath := GlobalParametersSetup."Free Text"
        else
            GlobalHugoPath := StaticHugoPath;

        Parameters := Parameters.Dictionary();
        Parameters.Add('baseurl', ParameterWS."Web Uri");
        Parameters.Add('restmethod', 'GET');
        Parameters.Add('path', ParameterWS."Web Uri");
        Parameters.Add('accept', ParameterWS."Value Text 1");
        Parameters.Add('Bearer', ParameterWS.Valor);
        ODATA.InitRequestGlobals('', ParameterWS."Value Text 1", '', ParameterWS.Valor, '', '');
        ODATA.SetBodyGlobal(RequestTxt);
        ODATA.CallRESTWebService(Parameters, HttpResponseMessage);
        result := HttpResponseMessage.Content.ReadAsStringAsync.Result;
        FileSystem := FileSystem.StreamWriter(GlobalHugoPath + 'HUGOITEM_RESET.xml');
        FileSystem.Write(result);
        FileSystem.Close();

        UpdateDTCommand(FALSE);
    end;

    procedure UpdateHugoParnerData()
    var
        ParameterWS: Record "FSN Parameter";
        Parameters: DotNet Dictionary_Of_T_U;
        HttpResponseMessage: DotNet HttpResponseMessage;
        result: Text;
        ODATA: Codeunit "FSN OData Conexion";
        Counter: Integer;
        Taxonomy: Text;
        HierarchyActiveTMP: Record "FSN Item Info. Extend" temporary;
        TaxonomiesTMP: Record "FSN Item Info. Extend" temporary;
        IsNewHugo: Boolean;
        FileSystem: DotNet StreamWriter;
        LSJson: Codeunit "FSN Windows Forms NET";
        jValueArr: array[100] of Text[1024];
        jObject: DotNet JObject;
        jObjectItem: DotNet JObject;
        jObjectImg: DotNet JObject;
        jObjectParent: DotNet JObject;
        JWriter: DotNet JsonWriter;
        i: Integer;
        DataExists: Boolean;
    begin
        SetRUNMode(GlobalCommand);
        UpdateDTCommand(TRUE);
        COMMIT;

        IF NOT ParameterWS.GET('HUGOAPP', 'PARTNER') THEN
            EXIT;

        GlobalParametersSetup.SETRANGE(GlobalParametersSetup."No.", 'HUGOPATH');
        if GlobalParametersSetup.Find('-') and (GlobalParametersSetup."Free Text" <> '') then
            GlobalHugoPath := GlobalParametersSetup."Free Text"
        else
            GlobalHugoPath := StaticHugoPath;

        Parameters := Parameters.Dictionary();
        Parameters.Add('baseurl', ParameterWS."Web Uri");
        Parameters.Add('restmethod', 'POST');
        Parameters.Add('path', ParameterWS."Web Uri");//Equal
        Parameters.Add('accept', ParameterWS."Value Text 1");
        Parameters.Add('Bearer', ParameterWS.Valor);
        Parameters.Add('httpcontent', 'OK');
        ODATA.InitRequestGlobals('', ParameterWS."Value Text 1", '', ParameterWS.Valor, '', '');
        ODATA.SetBodyGlobal(ParameterWS."String Parameters 1 Json");
        ODATA.CallRESTWebService(Parameters, HttpResponseMessage);
        result := HttpResponseMessage.Content.ReadAsStringAsync.Result;
        FileSystem := FileSystem.StreamWriter(GlobalHugoPath + 'HUGOITEM_PARTNER.xml');
        FileSystem.Write(result);
        FileSystem.Close();

        UpdateDTCommand(FALSE);
    end;

    procedure UpdateInventoryHugoSql() Msg: Text
    var
        SQLRead: Codeunit "FSN SQL Data Reader";
        SqlDataReaderNET: DotNet SqlDataReader;
        QueryTxt: Text;
        Index: Integer;
        j: Integer;
        lText001: Label 'Conection Error DB';
        lText002: Label 'Cant be suggest items';
        DistribLocCode: Code[10];
        "Query": Text;
        ItemCode: Text[20];
        ParentCode: Text[30];
        InventoryArray: array[100] of Integer;
        InventoryTxtArray: array[100] of Text[250];
        StoreIDArrary: array[100, 2] of Text[10];
        LSJson: Codeunit "FSN Windows Forms NET";
        ToggleMode: Boolean;
        jObject: DotNet JObject;
        jObjectQty: DotNet JObject;
        jObjectStores: DotNet JObject;
        jObjectParent: DotNet JObject;
        JWriter: DotNet JsonWriter;
        ParameterWS: Record "FSN Parameter";
        Parameters: DotNet Dictionary_Of_T_U;
        HttpResponseMessage: DotNet HttpResponseMessage;
        ODATA: Codeunit "FSN OData Conexion";
        Sucessffull: Boolean;
        FileSystem: DotNet StreamWriter;
        lQuery1: Label 'SELECT ex.No_ + [Unit of Measure] Code';
        lQuery2: Label ',ROUND(INTRANET.dbo.fn_getItemInventory(u.[Item No_],''%1'') / CASE WHEN ex.[Unit of Measure] = i.[Purch_ Unit of Measure] THEN u.[Qty_ per Unit of Measure] ELSE 1 END,0,1) %1';
        lQuery3: Label ',ex.[Hierarchy Parent Code] ParentCode';
        lQuery4: Label ' FROM ECOMMERCE.DBTIENDA.dbo.[FASANI$Item Info_ Extend] ex JOIN [DBTIENDA].dbo.FASANI$Item i ON ex.[No_]=i.[No_] JOIN [DBTIENDA].dbo.[FASANI$Item Unit of Measure] u ON i.No_= u.[Item No_] AND i.[Purch_ Unit of Measure] = u.Code';
        lQuery5: Label ' where [Entry Type]=5 AND [Sub Type] = 1 and [Line No_] = 100 AND ID=''HUGO'' AND [Blocked Ecommerce] = 0 AND ex.[Hierarchy Parent Code] IN (SELECT No_ FROM ECOMMERCE.DBTIENDA.dbo.[FASANI$Item Info_ Extend] ex WHERE [Unit of Measure]=''HUGO'' and [Free Text] <> '''')';
        dim: Integer;
    begin
        SetRUNMode(GlobalCommand);
        UpdateDTCommand(TRUE);
        COMMIT;

        IF NOT ParameterWS.GET('HUGOAPP', 'INVENTORY') THEN
            EXIT;

        GlobalParametersSetup.SETRANGE(GlobalParametersSetup."No.", 'HUGOPATH');
        if GlobalParametersSetup.Find('-') and (GlobalParametersSetup."Free Text" <> '') then
            GlobalHugoPath := GlobalParametersSetup."Free Text"
        else
            GlobalHugoPath := StaticHugoPath;

        Index := 1;
        ItemInfoExtend.RESET;
        ItemInfoExtend.SETRANGE(ItemInfoExtend."Entry Type", ItemInfoExtend."Entry Type"::Parameters);
        ItemInfoExtend.SETRANGE(ItemInfoExtend."Sub Type", ItemInfoExtend."Sub Type"::ItemSetting);
        ItemInfoExtend.SETRANGE(ItemInfoExtend."Unit of Measure", 'HUGOSTORE');
        IF NOT ItemInfoExtend.FIND('-') THEN
            EXIT;
        REPEAT
            IF (ItemInfoExtend."No." <> '') AND (ItemInfoExtend."Free Text" <> '') THEN BEGIN
                StoreIDArrary[Index] [1] := ItemInfoExtend."No.";
                StoreIDArrary[Index] [2] := ItemInfoExtend."Free Text";
                Index += 1;
                QueryTxt += STRSUBSTNO(lQuery2, ItemInfoExtend."No.");

            END;
        UNTIL ItemInfoExtend.NEXT = 0;

        dim := Index - 1;
        Query := lQuery1 + QueryTxt + lQuery3 + lQuery4 + lQuery5;
        FileSystem := FileSystem.StreamWriter(GlobalHugoPath + 'HUGOINVQ.xml');
        FileSystem.Write(Query);
        FileSystem.Close();

        Parameters := Parameters.Dictionary();
        Parameters.Add('baseurl', ParameterWS."Web Uri");
        Parameters.Add('restmethod', 'POST');
        Parameters.Add('path', ParameterWS."Web Uri");
        Parameters.Add('accept', ParameterWS."Value Text 1");
        Parameters.Add('Bearer', ParameterWS.Valor);
        Parameters.Add('httpcontent', 'OK');
        ODATA.InitRequestGlobals('', ParameterWS."Value Text 1", '', ParameterWS.Valor, '', '');

        DistribLocCode := 'INTRANET';

        SQLRead.ClearParams();
        SQLRead.SetDistributionLocation(DistribLocCode);
        SQLRead.SetQuery(Query);
        SQLRead.SetAction('OPEN');
        COMMIT;
        IF SQLRead.RUN THEN;
        IF NOT SQLRead.IsConnect THEN
            EXIT;

        SQLRead.SetAction('POST');
        COMMIT;
        IF SQLRead.RUN THEN;
        jObjectParent := jObjectParent.JObject();
        JWriter := jObjectParent.CreateWriter();
        JWriter.WritePropertyName('Object');
        JWriter.WriteStartArray();

        Index := 0;
        SQLRead.GetDataReader(SqlDataReaderNET);
        IF NOT ISNULL(SqlDataReaderNET) THEN
            WHILE SqlDataReaderNET.Read() DO BEGIN
                ToggleMode := TRUE;
                Index += 1;
                ItemCode := SqlDataReaderNET.Item('Code');
                ParentCode := SqlDataReaderNET.Item('ParentCode');
                FOR j := 1 TO dim DO BEGIN
                    InventoryArray[j] := SqlDataReaderNET.Item(StoreIDArrary[j] [1]);
                    IF InventoryArray[j] < 0 THEN
                        InventoryArray[j] := 0;
                    IF ToggleMode THEN
                        IF InventoryArray[j] > 0 THEN
                            ToggleMode := FALSE;
                END;
                ToggleMode := FALSE;
                jObjectQty := jObjectQty.JObject();
                jObject := jObject.JObject();
                FOR j := 1 TO dim DO BEGIN
                    jObjectStores := jObjectStores.JObject();
                    LSJson.WriterPropertyObject(jObjectStores, StoreIDArrary[j] [2], 1, '', InventoryArray[j], 0, 0T, 0DT, 0D, FALSE);
                    InventoryTxtArray[j] := jObjectStores.ToString();
                END;
                LSJson.WriterPropertyArrayObject(jObjectQty, 'qty', InventoryTxtArray, dim, 6);

                jObjectQty := jObjectQty.SelectToken('qty');
                LSJson.WriterPropertyObject(jObject, 'sku', 0, ItemCode, 0, 0, 0T, 0DT, 0D, FALSE);
                LSJson.WriterPropertyObject(jObject, 'qty', 6, jObjectQty.ToString(), 0, 0, 0T, 0DT, 0D, FALSE);
                LSJson.WriterPropertyObject(jObject, 'toggle_mode', 7, jObjectQty.ToString(), 0, 0, 0T, 0DT, 0D, ToggleMode);

                IF NOT ISNULL(jObject) THEN
                    JWriter.WriteRaw(jObject.ToString());
            END;

        JWriter.WriteEndArray();
        JWriter.Close();

        SQLRead.SetAction('CLOSE');
        COMMIT;
        IF SQLRead.RUN THEN;
        SQLRead.ClearParams();

        jObjectParent := jObjectParent.SelectToken('Object');
        IF ISNULL(jObjectParent) THEN
            EXIT;

        FileSystem := FileSystem.StreamWriter(GlobalHugoPath + 'HUGOINV.xml');
        FileSystem.Write(jObjectParent.ToString());
        FileSystem.Close();

        ODATA.SetBodyGlobal(jObjectParent.ToString());
        ODATA.CallRESTWebService(Parameters, HttpResponseMessage);

        COMMIT;
        FileSystem := FileSystem.StreamWriter(GlobalHugoPath + 'HUGOINV_R.xml');
        FileSystem.Write(HttpResponseMessage.ToString());
        FileSystem.Close();

        UpdateDTCommand(FALSE);
    end;

    procedure UpdateItemDescription2(ItemCode: Code[20])
    var
        Item: Record Item;
        Ingredient: Record "FSN Ingredient";
        IngredientXItem: record "FSN Ingredient Item Link";
        Description2: Text;
        NewPartDescription: Text[250];
        MaxLength: Integer;
    begin
        Clear(Description2);
        MaxLength := MaxStrLen(Item."Description 2");
        IngredientXItem.Reset();
        IngredientXItem.SetRange(ItemNo, ItemCode);
        if IngredientXItem.findset() then
            repeat
                if Ingredient.Get(IngredientXItem.Ingrediente) and (Ingredient.Description <> '') then
                    Description2 += Ingredient.Description;
            until IngredientXItem.next() = 0;
    end;

    procedure UpdateDynReset()
    begin
        UpdateDTCommand(TRUE);
        Commit();

        Item.Reset();

    end;

    procedure UpdateDynItem()
    begin

    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Controller", 'OnPOSEvent', '', true, true)]
    local procedure "LSC POS Controller_OnPOSEvent"
        (
        var PosEvent: Codeunit "LSC POS Event";
        var SuppressEvent: Boolean
        )
    var
        POSLines: Codeunit "LSC POS Trans. Lines";
        RecRef: RecordRef;
        POSLine_l: Record "LSC POS Trans. Line";
        POSDataTableColumn: Record "LSC POS Data Table Columns";
        EPosCtrl: Codeunit "LSC POS Control Interface";
        DelOrd: Record "LSC Delivery Order";
        OrderN: Code[20];
        Parameter: Record "FSN Parameter";
        HosPosStartup: Codeunit "LSC Hospitality POS Startup";
        POSTrans: Record "LSC POS Transaction";
        userRetail: Record "LSC Retail User";
        TenderTypeSetup: Record "LSC Tender Type Setup";
        Itemp: Text;
        POSSESSION: Codeunit "LSC POS Session";
        POSTransaction: Codeunit "LSC POS Transaction";
        XMLRequest: Text;
        XMLResponse: Text;
        RequestID: Text[50];
        PosMenuLineTemp: Record "LSC POS Menu Line";
        Processed: Boolean;
        MsgResult: Text;
        FSNUtility: Codeunit "FSN Utility";
        DelOr: Record "LSC Delivery Order";
        ItemPrice: Record "FSN Item Info. Extend";
        ItemPrice2: Record "FSN Item Info. Extend";
        PosBro: Record "LSC POS Browser Control";
        Url: text;
        PageImagen: Page TextCopy;
        retailPrice: Text;
        vipPrice: Text;
        baPrice: Text;
    begin
        RequestID := 'FSNCC';
        Processed := false;
        FSNUtility.InvokeGlobalChannel(XMLRequest, XMLResponse, RequestID, PosMenuLineTemp, Processed, MsgResult);
        IF Processed THEN begin
            if PosEvent.ActivePanel = '#POS' THEN
                if PosEvent.EventType in [
                    Enum::"LSC POS Event Type"::DATAROWDOUBLECLICK
                ] then begin
                    POSLines.GetCurrentLine(POSLine_l);
                    if StrPos(PosEvent.Sender, '#JOURNALHOMIN') > 0 then
                        if (POSLine_l."Entry Type" = POSLine_l."Entry Type"::Item) AND
                            (POSLine_l."Entry Status" = POSLine_l."Entry Status"::" ") THEN begin
                            ItemPrice.Reset();
                            ItemPrice.SetRange("No.", POSLine_l.Number);
                            ItemPrice.SetRange("Sub Type", ItemPrice."Sub Type"::ItemSetting);
                            if POSLine_l."Unit of Measure" <> '' then
                                ItemPrice.SetRange("Unit of Measure", POSLine_l."Unit of Measure");
                            IF ItemPrice.Find('-') then begin
                                repeat
                                    if ItemPrice.ID = 'RETAIL' then
                                        retailPrice := FORMAT(ItemPrice."Price Inc. Disc. Default");
                                    if ItemPrice.ID = 'VIP' then
                                        vipPrice := FORMAT(ItemPrice."Price Inc. Disc. Default");
                                    if ItemPrice.ID = 'VIP_BA' then
                                        baPrice := FORMAT(ItemPrice."Price Inc. Disc. Default");
                                until ItemPrice.Next() = 0;
                            end;
                            ItemPrice2.Reset();
                            ItemPrice2.SetRange("No.", ItemPrice."No.");
                            if POSLine_l."Unit of Measure" <> '' then
                                ItemPrice2.SetRange("Unit of Measure", POSLine_l."Unit of Measure");
                            IF ItemPrice2.Find('-') then begin
                                repeat
                                    IF ItemPrice2."Image Link" <> '' then
                                        Itemli.Add(StrSubstNo('<img src="https://fasani.b-cdn.net/productos/ecommerce/%1" alt="product">', ItemPrice2."Image Link"));
                                until ItemPrice2.Next() = 0;
                            end;
                            //Itemp := POSLine_l.Number;
                            //Url := '<img src = "' + it + '"/>';
                            Url := StrSubstNo(htmlTemplate(), retailPrice, vipPrice, baPrice);
                            PageImagen.CopyTxt(Url);
                            PageImagen.Run();
                        end;
                end;
        END;
    END;

    local procedure htmlTemplate(): Text
    var
        chtml: Text;
        Item: Text;
    begin
        chtml := '<!DOCTYPE html><html lang="en"><head>  <meta charset="UTF-8">  <meta name="viewport" content="width=device-width, initial-scale=1.0"></head><body>  <style>    body {      margin: 0;      padding: 0;      height: 100vh;      display: flex;      flex-direction: column;      justify-content: center;      align-items: center;    }    .container {      width: 100%;      max-width: 520px;      display: flex;      margin: 0;      padding: 0;    }    .carrusel {      position: relative;      overflow: hidden;      width: 500px;      border-radius: 4px;    }    .carrusel ul {      position: relative;      overflow: hidden;      margin: 0;      padding: 0;      height: 400px;      list-style: none;    }    .carrusel ul li {      position: relative;      display: block;      float: left;      margin: 0;      padding: 0;      height: 500px;    }    img {      width: 100%;      height: 100%;      object-fit: cover;    }    a.control_prev,    a.control_next {      position: absolute;      top: 50%;      z-index: 999;      display: block;      padding: 4% 3%;      width: auto;      height: auto;      color: #000;      text-decoration: none;      font-weight: 600;      font-size: 18px;      opacity: 0.8;      cursor: pointer;    }    a.control_prev:hover,    a.control_next:hover {      opacity: 1;      -webkit-transition: all 0.2s ease;    }    a.control_prev {      border-radius: 0 2px 2px 0;    }    a.control_next {      right: 0;      border-radius: 2px 0 0 2px;    }    .discounts-container {      display: flex;      flex-direction: column;      align-items: center;      justify-content: space-around;      gap: 10px;      width: 35%;      height: 100%;      align-items: center;      justify-content: center;    }    .item {      text-align: center;      width: 100%;      padding: 10px;    }    .item h3,    p {      margin: 0;      padding: 0;      font-weight: bold;      font-size: 24px;      font-family: Tahoma, Geneva, Verdana, sans-serif;    }    .retail {      color: #008996;    }    .vip {      color: #ff35f5;    }    .agricola {      color: #636363;    }.carousel {      width: 100%;      height: 100%;      display: flex;      flex-direction: row;      overflow: hidden;      overflow-x: scroll;    }  </style><div class="container">    <div class="carousel">';
        foreach Item in Itemli
        do chtml += Item;
        chtml += '</div>    <div class="discounts-container">      <div class="item retail">        <h3>Precio General</h3>        <p>$ %1</p>      </div>      <div class="item vip">        <h3>Precio Vip</h3>        <p>$ %2</p>      </div>      <div class="item agricola">        <h3>Precio Vip Agrícola</h3>        <p>$ %3</p></div></div></div></body></html>';
        exit(chtml);
    end;
    #endregion
    #region [subscriptions]
    [EventSubscriber(ObjectType::Page, Page::"LSC Retail Item Card", 'OnQueryClosePageEvent', '', true, true)]
    local procedure "Retail Item Card_OnQueryClosePageEvent"
    (
        var Rec: Record "Item";
        var AllowClose: Boolean
    )
    begin
        UpdateItemDescription2(Rec."No.");
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"FSN Utility", 'OnInvokeGlobalChannelEvent', '', false, false)]
    local procedure OnInvokeGlobalChannelEvent(var XMLRequest: Text; var XMLResponse: Text; var RequestID: Text[50]; var POSMenuLine: Record "LSC POS Menu Line"; var Processed: Boolean; var MsgResult: Text);
    begin
        if RequestID = 'UOM_VERIFY' then
            processed := VerifyBlockedItem(XMLRequest, XmlResponse);
    end;
    #endregion
}
codeunit 50026 "FSN Delivery Store Link"
{
    TableNo = "LSC POS Menu Line";
    trigger OnRun()
    begin
        Case Command of
            'DEL_MATRIX_API':  //Internal code function, is not menu button
                GetDistanceMatrixJson();
        End;
    end;

    var
        StoreLink: Record "FSN Store Link";
        GlobalUrl: Text[250];
        GlobalRec: Record "FSN Store Link";
        POSMenuLIneTmp: Record "LSC POS Menu Line" temporary;
        POSSESSION: Codeunit "LSC POS Session";
        POSGUI: Codeunit "LSC POS GUI";
        EPOSControlInterface: Codeunit "LSC POS Control Interface"; //"EPOS Control Interface";
        POSTransaction: Codeunit "LSC POS Transaction";
        Text000: Label 'Last Valid Time for street %1 is %2.\%3';


    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Zoom Functions", 'OnBeforeCreateRecordZoomDataSet', '', true, true)]
    local procedure "LSC POS Zoom Functions_OnBeforeCreateRecordZoomDataSet"
    (
        var POSDataTable: Record "LSC POS Data Table";
        var POSPairValue: Record "LSC POS Pair Value"
    )
    begin

        if POSDataTable."Data Table ID" = '#DEL-ORDERSDETZOOM' then
            IF POSPairValue.Find('-') THEN BEGIN
                repeat
                    IF POSPairValue."Field No." = 50004 THEN begin //ALTER KEY
                        POSSession.SetValue('#FSN-ALTERKEY', POSPairValue."Text Value");

                    end;
                UNTIL POSPairValue.NEXT = 0;
            end;
    end;

    procedure ShowPanelStoreSuggest(pParameter: Record "LSC POS Menu Line")
    var
        DeliveryOrd: Record "LSC Delivery Order";
        DelStreet: Record "LSC Delivery Street";
        DelStreetTemp: Record "LSC Delivery Street" temporary;
        StoreLinkTmp: Record "FSN Store Link" temporary;
        StoreLinkLocal: Record "FSN Store Link";
        RecRefTmp: RecordRef;
        interfaceIntAlterKey: Integer;
        lTxt1: Label 'Suggest unique %1 %2';
        lTxt2: Label 'Seleccione calle reparto valida';

    begin
        interfaceIntAlterKey := 0;
        if Evaluate(interfaceIntAlterKey, POSSESSION.GetValue('#FSN-ALTERKEY')) then;

        DelStreet.RESET;
        DelStreet.SETRANGE("FSN Alter Key", interfaceIntAlterKey);
        IF NOT DelStreet.FINDFIRST THEN
            EXIT;

        StoreLinkTmp.RESET;
        StoreLinkTmp.DELETEALL;

        StoreLinkLocal.RESET;
        StoreLinkLocal.SETCURRENTKEY("Km Between Points");
        StoreLinkLocal.SETRANGE(StoreLinkLocal.Type, StoreLinkLocal.Type::StreetAlterKey);
        StoreLinkLocal.SETRANGE(StoreLinkLocal."Parent Code", DelStreet."FSN Alter Key Text");
        IF DelStreet."FSN Distance Order Type" = DelStreet."FSN Distance Order Type"::"Distance Driver" THEN BEGIN
            StoreLinkLocal.SETCURRENTKEY(Sort, "Km Distance Driver");
            StoreLinkLocal.SETFILTER(StoreLinkLocal."Km Distance Driver", '>0&<=%1', DelStreet."FSN Distance Show Km.");
        END ELSE
            StoreLinkLocal.SETFILTER(StoreLinkLocal."Km Between Points", '>0&<=%1', DelStreet."FSN Distance Show Km.");
        IF StoreLinkLocal.FIND('-') THEN BEGIN
            REPEAT
                StoreLinkTmp := StoreLinkLocal;
                IF StoreLinkTmp.INSERT THEN;
            UNTIL StoreLinkLocal.NEXT = 0;
        END;

        DelStreetModifyPriority(DelStreet, StoreLinkTmp);

        StoreLinkTmp.Reset();
        IF StoreLinkTmp.FIND('-') THEN BEGIN
            RecRefTmp.GETTABLE(StoreLinkTmp);
            IF DelStreet."FSN Distance Order Type" = DelStreet."FSN Distance Order Type"::"Distance Driver" THEN
                POSTransaction.LookUpEx(FALSE, '#STORELINKS_DISTDRIV', '', RecRefTmp)
            ELSE
                POSTransaction.LookUpEx(FALSE, '#STORELINKS_DISTANCE', '', RecRefTmp);
            RecRefTmp.CLOSE;
        END ELSE BEGIN
            DelStreet.CALCFIELDS("Restaurant Name");
            POSGUI.PosMessage(STRSUBSTNO(lTxt1, DelStreet."Restaurant No.", DelStreet."Restaurant Name"));
        END;
        COMMIT;
    end;

    procedure DelStreetModifyPriority(pDelStreet_l: Record "LSC Delivery Street"; var pStoreLinkTmp: Record "FSN Store Link" temporary)
    var
        StoreGroup_l: Record "LSC Store Group";
        StoreGrouPSetup_l: Record "LSC Store Group Setup";
        GroupInStoreTableTmp: Record "LSC Store" temporary;
        NoSortByGroup: Integer;
    begin
        GroupInStoreTableTmp.RESET;
        GroupInStoreTableTmp.DELETEALL;
        CLEAR(GroupInStoreTableTmp);

        pStoreLinkTmp.RESET;
        StoreGrouPSetup_l.RESET;
        IF pStoreLinkTmp.FIND('-') THEN
            REPEAT
                StoreGrouPSetup_l.SETRANGE(StoreGrouPSetup_l."Store Code", pStoreLinkTmp."Store No.");
                IF StoreGrouPSetup_l.FIND('-') THEN
                    REPEAT
                        IF StoreGroup_l.GET(StoreGrouPSetup_l."Store Group") AND (StoreGroup_l."Distribution Group Code" = 'DAF') THEN BEGIN
                            IF NOT GroupInStoreTableTmp.GET(StoreGrouPSetup_l."Store Group") THEN BEGIN
                                GroupInStoreTableTmp."No." := StoreGrouPSetup_l."Store Group";
                                GroupInStoreTableTmp."Fraud Sort Field" := pStoreLinkTmp."Km Between Points";
                                IF pDelStreet_l."FSN Distance Order Type" = pDelStreet_l."FSN Distance Order Type"::"Distance Driver" THEN
                                    GroupInStoreTableTmp."Fraud Sort Field" := pStoreLinkTmp."Km Distance Driver";
                                GroupInStoreTableTmp.INSERT;
                            END ELSE BEGIN
                                IF pStoreLinkTmp."Link Type" IN [pStoreLinkTmp."Link Type"::DeliveryStore, pStoreLinkTmp."Link Type"::DeliveryStoreSuper] THEN
                                    IF pDelStreet_l."FSN Distance Order Type" = pDelStreet_l."FSN Distance Order Type"::"Distance Driver" THEN BEGIN
                                        IF GroupInStoreTableTmp."Fraud Sort Field" > pStoreLinkTmp."Km Distance Driver" THEN BEGIN
                                            GroupInStoreTableTmp."Fraud Sort Field" := pStoreLinkTmp."Km Distance Driver";
                                            GroupInStoreTableTmp.MODIFY;
                                        END;
                                    END ELSE BEGIN
                                        IF GroupInStoreTableTmp."Fraud Sort Field" > pStoreLinkTmp."Km Between Points" THEN BEGIN
                                            GroupInStoreTableTmp."Fraud Sort Field" := pStoreLinkTmp."Km Between Points";
                                            GroupInStoreTableTmp.MODIFY;
                                        END;
                                    END;
                            END;
                        END;
                    UNTIL StoreGrouPSetup_l.NEXT = 0;
            UNTIL pStoreLinkTmp.NEXT = 0;

        NoSortByGroup := 10100;
        GroupInStoreTableTmp.RESET;
        GroupInStoreTableTmp.SETCURRENTKEY("Fraud Sort Field");
        IF GroupInStoreTableTmp.FIND('-') THEN
            REPEAT
                StoreGrouPSetup_l.RESET;
                StoreGrouPSetup_l.SETRANGE(StoreGrouPSetup_l."Store Group", GroupInStoreTableTmp."No.");
                IF StoreGrouPSetup_l.FIND('-') THEN
                    REPEAT
                        pStoreLinkTmp.RESET;
                        pStoreLinkTmp.SETRANGE(pStoreLinkTmp."Store No.", StoreGrouPSetup_l."Store Code");
                        IF pStoreLinkTmp.FIND('-') THEN BEGIN
                            IF pStoreLinkTmp.Sort > 0 THEN
                                pStoreLinkTmp.Sort += 11000000;

                            pStoreLinkTmp.Sort += NoSortByGroup;
                            IF pStoreLinkTmp."Link Type" IN [pStoreLinkTmp."Link Type"::DeliveryStoreSuper, pStoreLinkTmp."Link Type"::DeliveryStore] THEN
                                pStoreLinkTmp.Sort -= 100;

                            pStoreLinkTmp.MODIFY;
                        END;
                    UNTIL StoreGrouPSetup_l.NEXT = 0;

                NoSortByGroup += 10000;
            UNTIL (GroupInStoreTableTmp.NEXT = 0) OR (NoSortByGroup > 10990000);
    end;

    procedure DelStreetCreateGroupStore(pStoreNo: Code[10])
    var
        StoreSetup: Record "FSN Store Link";
        StoreLinks_l: Record "FSN Store Link";
        StoreLinkNew: Record "FSN Store Link";
        Store_l: Record "LSC Store";
        StoreTmp: Record "LSC Store" temporary;
        Km: Decimal;
        DistanceKm: Decimal;
    begin
        StoreLinks_l.RESET;
        StoreLinks_l.SETRANGE(StoreLinks_l.Type, StoreLinks_l.Type::StoreGroup);
        StoreLinks_l.SETRANGE(StoreLinks_l."Parent Code", pStoreNo);
        StoreLinks_l.DELETEALL;

        StoreLinks_l.RESET;
        StoreLinks_l.SETCURRENTKEY("Parent Code", "Link Type", Sort, "Km Between Points");
        StoreLinks_l.SETRANGE(StoreLinks_l."Parent Code", pStoreNo);

        IF NOT StoreLinks_l.FINDFIRST THEN
            EXIT;

        IF NOT Store_l.GET(pStoreNo) THEN
            EXIT;

        IF (Store_l.Latitude <> StoreLinks_l.Latitude) OR (Store_l.Longitude <> StoreLinks_l.Longitude) THEN BEGIN
            StoreLinks_l.Longitude := Store_l.Longitude;
            StoreLinks_l.Latitude := Store_l.Latitude;
            StoreLinks_l.MODIFY;
        END;

        Km := StoreLinks_l."Distance Allow Km.";
        IF Km <= 0 THEN
            Km := 10;

        Store_l.RESET;
        IF Store_l.FIND('-') THEN
            REPEAT
                IF (Store_l.Latitude <> 0) AND (Store_l.Longitude <> 0) THEN BEGIN
                    DistanceKm :=
                      GetDistanceGeographic(StoreLinks_l.Latitude, StoreLinks_l.Longitude, Store_l.Latitude, Store_l.Longitude);
                    DistanceKm :=
                      ROUND(DistanceKm, 0.01);

                    IF DistanceKm <= Km THEN
                        IF NOT StoreTmp.GET(Store_l."No.") THEN BEGIN
                            StoreTmp := Store_l;
                            StoreTmp."Fraud Sort Field" := DistanceKm;
                            StoreTmp.INSERT;
                        END;
                END;
            UNTIL Store_l.NEXT = 0;

        CLEAR(StoreLinkNew);
        StoreLinkNew.INIT;
        StoreLinkNew.Type := StoreLinkNew.Type::StoreGroup;
        StoreLinkNew.VALIDATE("Parent Code", pStoreNo);

        StoreTmp.RESET;
        IF StoreTmp.FIND('-') THEN
            REPEAT

                StoreLinkNew.VALIDATE("Store No.", StoreTmp."No.");
                StoreLinkNew."Distance Allow Km." := Km;
                StoreLinkNew."Km Between Points" := StoreTmp."Fraud Sort Field";

                IF StoreSetup.GET(StoreSetup.Type::StoreSetup, StoreTmp."No.", StoreSetup."Link Type"::DeliveryStoreSuper, '') THEN
                    StoreLinkNew."Link Type" := StoreLinkNew."Link Type"::DeliveryStoreSuper
                ELSE
                    IF StoreSetup.GET(StoreSetup.Type::StoreSetup, StoreTmp."No.", StoreSetup."Link Type"::DeliveryStore, '') THEN
                        StoreLinkNew."Link Type" := StoreLinkNew."Link Type"::DeliveryStore
                    ELSE
                        StoreLinkNew."Link Type" := StoreLinkNew."Link Type"::NormalStore;

                StoreLinkNew.INSERT;
            UNTIL StoreTmp.NEXT = 0;
    end;

    procedure GetDistanceGeographic(pLat1: Decimal; pLong1: Decimal; pLat2: Decimal; pLong2: Decimal): Decimal
    var
        LS_NetMath: DotNet Math;
        PI: Decimal;
        lLat: Decimal;
        lLong: Decimal;
        DataDiff: Decimal;
    begin
        PI := 3.14159265358979323;
        lLat := (pLat1 - pLat2) * (PI / 180);
        lLong := (pLong1 - pLong2) * (PI / 180);
        pLat1 := pLat1 * (PI / 180);
        pLat2 := pLat2 * (PI / 180);

        DataDiff :=
          LS_NetMath.Pow(LS_NetMath.Sin(lLat / 2), 2) +
          LS_NetMath.Cos(pLat1) *
          LS_NetMath.Cos(pLat2) *
          LS_NetMath.Pow(LS_NetMath.Sin(lLong / 2), 2);

        DataDiff := 2 *
          LS_NetMath.Atan2(LS_NetMath.Sqrt(DataDiff), LS_NetMath.Sqrt(1 - DataDiff));

        DataDiff := DataDiff * 6378;
        DataDiff := ROUND(DataDiff, 0.01, '<');

        EXIT(DataDiff);
    end;

    procedure DelStreetSetupExists(var MsgError: Text): Boolean
    var
        StoreSetup: Record "FSN Store Link";
        lText001: Label 'Setup not exists. None stores CallCenter Super.';
        lText002: Label 'Setup not exists. None stores CallCenter.';
    begin

        MsgError := lText001;

        StoreSetup.RESET;
        StoreSetup.SETCURRENTKEY(Type, "Parent Code", "Link Type", "Store No.");
        StoreSetup.SETRANGE(StoreSetup.Type, StoreSetup.Type::StoreSetup);
        StoreSetup.SETFILTER(StoreSetup."Parent Code", '<>%1', '');
        StoreSetup.SETRANGE(StoreSetup."Link Type", StoreSetup."Link Type"::DeliveryStoreSuper);
        IF NOT StoreSetup.FINDFIRST THEN
            EXIT(FALSE);

        MsgError := lText002;
        StoreSetup.RESET;
        StoreSetup.SETCURRENTKEY(Type, "Parent Code", "Link Type", "Store No.");
        StoreSetup.SETRANGE(StoreSetup.Type, StoreSetup.Type::StoreSetup);
        StoreSetup.SETFILTER(StoreSetup."Parent Code", '<>%1', '');
        StoreSetup.SETRANGE(StoreSetup."Link Type", StoreSetup."Link Type"::DeliveryStore);
        IF NOT StoreSetup.FINDFIRST THEN
            EXIT(FALSE);

        EXIT(TRUE);
    end;

    procedure DelSuggestStoreText(pDelStreet: Record "LSC Delivery Street"; pTypeFilter: Integer): Text[250]
    var
        ResponseText: Text;
        StoreLinks: Record "FSN Store Link";
        DescriptFilter: Text;
        Limit: Integer;
        SeparateChar: Text[1];
        IncLimit: Integer;
        fsnAlterKey: Text;
        StoreLinksTmp: Record "FSN Store Link" temporary;
        EPOSControlInterface: Codeunit "LSC POS Control Interface";
    begin
        //if Evaluate(fsnAlterKey, EPOSControlInterface.GetValue('#fsnAlterKey')) then
        IF pDelStreet."FSN Alter Key" <= 0 THEN
            EXIT('');

        //POSSESSION.SetValue('SLKFILTER', pDelStreet."FSN Alter Key Text");

        IF (pDelStreet."FSN Last Valid Time" <> 0T) AND (TIME > pDelStreet."FSN Last Valid Time") AND (pTypeFilter = 0) THEN BEGIN
            //COMMIT;
            Exit(STRSUBSTNO(Text000, pDelStreet."Street Name", FORMAT(pDelStreet."FSN Last Valid Time"), pDelStreet.Restriction));
        END;
        Limit := 100;
        IncLimit := 0;
        ResponseText := '';
        SeparateChar := '-';

        CASE pTypeFilter OF
            0:
                DescriptFilter := '<3';//CallCenter only
            1:
                DescriptFilter := '=3';
            2:
                BEGIN
                    DescriptFilter := '<3';
                    SeparateChar := '|';
                    Limit := 5;
                END;
            3:
                BEGIN
                    DescriptFilter := '=3';
                    SeparateChar := '|';
                    Limit := 5;
                END;
            4:
                BEGIN
                    DescriptFilter := '>=0';
                    Limit := 20;
                END;
            ELSE
                DescriptFilter := '<3';
        END;

        StoreLinks.RESET;
        StoreLinks.SETRANGE(StoreLinks.Type, StoreLinks.Type::StreetAlterKey);
        StoreLinks.SETRANGE(StoreLinks."Parent Code", pDelStreet."FSN Alter Key Text");
        StoreLinks.SETFILTER(StoreLinks."Link Type", DescriptFilter);
        StoreLinks.SETFILTER(StoreLinks."Km Between Points", '<=%1', pDelStreet."FSN Distance Show Km.");

        IF pTypeFilter = 4 THEN BEGIN
            StoreLinksTmp.RESET;
            StoreLinksTmp.DELETEALL;
            CLEAR(StoreLinksTmp);
            StoreLinks.SETCURRENTKEY(Sort, StoreLinks."Km Between Points");
            IF pDelStreet."FSN Distance Order Type" = pDelStreet."FSN Distance Order Type"::"Distance Driver" THEN BEGIN
                StoreLinks.SETCURRENTKEY(Sort, "Km Distance Driver");
                StoreLinks.SETFILTER(StoreLinks."Km Distance Driver", '>0&<=%1', pDelStreet."FSN Distance Show Km.");
            END;
            ResponseText := pDelStreet."Restaurant No." + SeparateChar;
            IF StoreLinks.FINDSET THEN
                REPEAT
                    StoreLinksTmp := StoreLinks;
                    StoreLinksTmp.INSERT;
                UNTIL StoreLinks.NEXT = 0;

            DelStreetModifyPriority(pDelStreet, StoreLinksTmp);

            StoreLinksTmp.RESET;
            StoreLinksTmp.SETCURRENTKEY(Sort, StoreLinksTmp."Km Between Points");
            IF pDelStreet."FSN Distance Order Type" = pDelStreet."FSN Distance Order Type"::"Distance Driver" THEN
                StoreLinksTmp.SETCURRENTKEY(Sort, "Km Distance Driver");
            IF StoreLinksTmp.FINDSET THEN
                REPEAT
                    IF pDelStreet."Restaurant No." <> StoreLinksTmp."Store No." THEN
                        ResponseText += StoreLinksTmp."Store No." + SeparateChar;
                UNTIL StoreLinksTmp.NEXT = 0;

        END ELSE BEGIN
            StoreLinks.SETCURRENTKEY("Parent Code", "Link Type", Sort, "Km Distance Driver");
            IF NOT StoreLinks.FINDSET THEN
                StoreLinks.SETFILTER(StoreLinks."Km Between Points", '<=%1', pDelStreet."FSN Distance Allow Km.");
            IF NOT StoreLinks.FINDSET THEN
                ResponseText := pDelStreet."Restaurant No." + SeparateChar
            ELSE BEGIN
                ResponseText += pDelStreet."Restaurant No." + SeparateChar;
                REPEAT
                    IncLimit += 1;
                    IF (StoreLinks."Store No." <> '') AND (StoreLinks."Store No." <> pDelStreet."Restaurant No.") THEN BEGIN
                        ResponseText += StoreLinks."Store No." + SeparateChar;
                    END;
                UNTIL (StoreLinks.NEXT = 0) OR (Limit < IncLimit);
            END;
        END;

        IF ResponseText <> '' THEN BEGIN
            ResponseText := COPYSTR(ResponseText, 1, STRLEN(ResponseText) - 1);
        END;
        IF pTypeFilter > 3 THEN
            EXIT(COPYSTR(ResponseText, 1, 250));

        EXIT(COPYSTR(ResponseText, 1, 30));
    end;

    procedure DelStreetUpdateStoreContext(pDeliveryStreet: Record "LSC Delivery Street"; var pMsgError: Text): Boolean
    var
        StoreLink_l: Record "FSN Store Link";
        Store_l: Record "LSC Store";
        StoreSetup: Record "FSN Store Link";
        StoreLinkNew: Record "FSN Store Link";
        StoreLinkTMP: Record "FSN Store Link" temporary;
        NewRestTmp: Record "LSC Store" temporary;
        StoreTmp: Record "LSC Store" temporary;
        KmAllow: Decimal;
        DistanceKm: Decimal;
        StringStoreCallCenter: Text;
        StringStoreCCAlternative: Text;
        SalesOK: Boolean;
        RestChangeOk: Boolean;
        NewRestCode: Code[10];
        KmShow: Decimal;
        lText001: Label 'Setup street incomplete.';
        lText002: Label 'Setup Store %1 not found.';
    begin
        StoreTmp.RESET;
        StoreTmp.DELETEALL;
        StoreLinkTMP.RESET;
        StoreLinkTMP.DELETEALL;
        CLEAR(StoreLinkTMP);
        CLEAR(StoreTmp);
        CLEAR(StringStoreCallCenter);
        CLEAR(StringStoreCCAlternative);

        pMsgError := lText001;
        IF (pDeliveryStreet."Street Name" = '') OR
          (pDeliveryStreet."Number from" <> 1) OR
          (pDeliveryStreet."Post Code" = '') OR
          (pDeliveryStreet."Number to" <> 1)
          THEN
            EXIT(FALSE);

        IF (pDeliveryStreet."FSN Latitude" = 0) OR (pDeliveryStreet."FSN Longitude" = 0) THEN
            EXIT(FALSE);

        IF pDeliveryStreet."FSN Alter Key" = 0 THEN
            pDeliveryStreet.MODIFY(TRUE);

        IF pDeliveryStreet."FSN Alter Key" = 0 THEN
            EXIT(FALSE);

        KmAllow := pDeliveryStreet."FSN Distance Allow Km.";
        IF KmAllow <= 0 THEN
            KmAllow := 10;//Static

        KmShow := pDeliveryStreet."FSN Distance Show Km.";
        IF KmShow <= 0 THEN
            KmShow := 7;//Static


        StoreLinkNew.RESET;
        StoreLinkNew.SETRANGE(StoreLinkNew.Type, StoreLinkNew.Type::StreetAlterKey);
        StoreLinkNew.SETRANGE(StoreLinkNew."Parent Code", pDeliveryStreet."FSN Alter Key Text");
        IF StoreLinkNew.FIND('-') THEN
            REPEAT
                StoreLinkTMP := StoreLinkNew;
                StoreLinkTMP.INSERT;
            UNTIL StoreLinkNew.NEXT = 0;
        StoreLinkNew.DELETEALL;

        Store_l.RESET;
        IF Store_l.FIND('-') THEN
            REPEAT
                IF (Store_l.Latitude <> 0) AND (Store_l.Longitude <> 0) THEN BEGIN
                    DistanceKm :=
                      GetDistanceGeographic(pDeliveryStreet."FSN Latitude", pDeliveryStreet."FSN Longitude", Store_l.Latitude, Store_l.Longitude);
                    DistanceKm :=
                      ROUND(DistanceKm, 0.01);
                    IF DistanceKm <= KmAllow THEN
                        IF NOT StoreTmp.GET(Store_l."No.") THEN BEGIN
                            StoreTmp := Store_l;
                            StoreTmp."Fraud Sort Field" := DistanceKm;
                            StoreTmp.INSERT;
                        END;
                END;
            UNTIL Store_l.NEXT = 0;

        pMsgError := '';

        CLEAR(StoreLinkNew);
        CLEAR(NewRestTmp);
        CLEAR(NewRestCode);

        SalesOK := FALSE;

        StoreTmp.RESET;
        StoreTmp.SETCURRENTKEY("Fraud Sort Field");
        IF StoreTmp.FIND('-') THEN
            REPEAT
                RestChangeOk := FALSE;

                StoreLinkNew.INIT;
                StoreLinkNew.Type := StoreLinkNew.Type::StreetAlterKey;
                StoreLinkNew.VALIDATE("Parent Code", COPYSTR(pDeliveryStreet."FSN Alter Key Text", 1, MAXSTRLEN(StoreLinkNew."Parent Code")));

                StoreLinkNew.VALIDATE("Store No.", StoreTmp."No.");
                StoreLinkNew."Distance Allow Km." := KmAllow;
                StoreLinkNew."Km Between Points" := StoreTmp."Fraud Sort Field";

                IF StoreSetup.GET(StoreSetup.Type::StoreSetup, StoreTmp."No.", StoreSetup."Link Type"::DeliveryStoreSuper, '') THEN BEGIN
                    StoreLinkNew."Link Type" := StoreLinkNew."Link Type"::DeliveryStoreSuper;

                    IF KmShow >= StoreTmp."Fraud Sort Field" THEN
                        StringStoreCallCenter += StoreTmp."No." + '-';

                    RestChangeOk := TRUE;
                END ELSE
                    IF StoreSetup.GET(StoreSetup.Type::StoreSetup, StoreTmp."No.", StoreSetup."Link Type"::DeliveryStore, '') THEN BEGIN
                        StoreLinkNew."Link Type" := StoreLinkNew."Link Type"::DeliveryStore;

                        IF KmShow >= StoreTmp."Fraud Sort Field" THEN
                            StringStoreCallCenter += StoreTmp."No." + '-';

                        RestChangeOk := TRUE;
                    END ELSE BEGIN
                        StoreLinkNew."Link Type" := StoreLinkNew."Link Type"::NormalStore;
                        IF KmShow >= StoreTmp."Fraud Sort Field" THEN
                            StringStoreCCAlternative += StoreTmp."No." + '-';
                    END;

                IF RestChangeOk THEN
                    IF NOT NewRestTmp.GET(StoreTmp."No.") THEN BEGIN
                        NewRestTmp := StoreTmp;
                        NewRestTmp.INSERT;
                    END;

                IF StoreLinkTMP.GET(StoreLinkNew.Type, StoreLinkNew."Parent Code", StoreLinkNew."Link Type", StoreLinkNew."Store No.") THEN
                    IF (ROUND(StoreLinkTMP."Parent Latitude", 0.00001, '<') = ROUND(StoreLinkNew."Parent Latitude", 0.00001, '<')) AND
                      (ROUND(StoreLinkTMP."Parent Longitude", 0.00001, '<') = ROUND(StoreLinkNew."Parent Longitude", 0.00001, '<')) AND
                      (ROUND(StoreLinkTMP.Latitude, 0.00001, '<') = ROUND(StoreLinkNew.Latitude, 0.00001, '<')) AND
                      (ROUND(StoreLinkTMP.Longitude, 0.00001, '<') = ROUND(StoreLinkNew.Longitude, 0.00001, '<')) AND
                      (ROUND(StoreLinkTMP."Km Between Points", 0.01, '<') = ROUND(StoreLinkNew."Km Between Points", 0.01, '<')) THEN BEGIN//Round 0.1
                        StoreLinkNew."Km Distance Driver" := StoreLinkTMP."Km Distance Driver";
                        StoreLinkNew."Time Driver Min." := StoreLinkTMP."Time Driver Min.";
                    END;

                StoreLinkNew.INSERT;
                SalesOK := TRUE;

            UNTIL StoreTmp.NEXT = 0;

        NewRestTmp.RESET;
        NewRestTmp.SETCURRENTKEY(NewRestTmp."Fraud Sort Field");
        IF NewRestTmp.FIND('-') THEN
            NewRestCode := NewRestTmp."No.";

        RestChangeOk := FALSE;
        IF SalesOK THEN BEGIN
            StoreSetup.RESET;
            StoreSetup.SETCURRENTKEY("Parent Code", "Link Type", Sort, "Km Between Points");
            StoreSetup.SETRANGE(StoreSetup.Type, StoreSetup.Type::StreetAlterKey);
            StoreSetup.SETRANGE(StoreSetup."Parent Code", COPYSTR(pDeliveryStreet."FSN Alter Key Text", 1, MAXSTRLEN(StoreSetup."Parent Code")));
            StoreSetup.SETFILTER(StoreSetup."Store No.", '<>%1', '');

            IF StoreSetup.FINDFIRST THEN
                IF (pDeliveryStreet."Restaurant No." <> NewRestCode) AND (NewRestCode <> '') THEN BEGIN
                    pDeliveryStreet."Restaurant No." := NewRestCode;
                    RestChangeOk := TRUE;
                END;

            IF StringStoreCallCenter <> '' THEN
                StringStoreCallCenter := COPYSTR(StringStoreCallCenter, 1, STRLEN(StringStoreCallCenter) - 1);
            IF StringStoreCCAlternative <> '' THEN
                StringStoreCCAlternative := COPYSTR(StringStoreCCAlternative, 1, STRLEN(StringStoreCCAlternative) - 1);


            pDeliveryStreet."FSN Stores Suggest" := COPYSTR(StringStoreCallCenter, 1, 100);
            pDeliveryStreet."FSN Stores Complement" := COPYSTR(StringStoreCCAlternative, 1, 100);
            IF pDeliveryStreet."FSN Stores Suggest" = '' THEN
                pDeliveryStreet."FSN Stores Suggest" := pDeliveryStreet."Restaurant No.";

            IF pDeliveryStreet."FSN Stores Complement" = '' THEN
                pDeliveryStreet."FSN Stores Complement" := pDeliveryStreet."Restaurant No.";


            pDeliveryStreet."FSN Distance Order Type" := pDeliveryStreet."FSN Distance Order Type"::"Distance Plane";
            pDeliveryStreet.MODIFY(RestChangeOk);

        END ELSE BEGIN

            pDeliveryStreet."FSN Stores Suggest" := pDeliveryStreet."Restaurant No.";
            pDeliveryStreet."FSN Stores Complement" := pDeliveryStreet."Restaurant No.";
            pDeliveryStreet."FSN Distance Order Type" := pDeliveryStreet."FSN Distance Order Type"::"Distance Plane";
            pDeliveryStreet.MODIFY;

        END;
        EXIT(TRUE);
    end;

    procedure GetStoreLinksSuggest(pRecRef: RecordRef): Text[250]
    var
        DeliveryOrder_l: Record "LSC Delivery Order";
        DelStreet_l: Record "LSC Delivery Street";
    //DelFuncExt: Codeunit "50028";
    begin

        /*CLEAR(DeliveryOrder_l);
        pRecRef.Gettable(DeliveryOrder_l);
        EPOSControlInterface.GetRecordZoomData(pRecRef, '#DEL-ORDER-DETZOOM');*/

        DeliveryOrder_l."FSN Alter Key" := pRecRef.Field(DeliveryOrder_l.FieldNo("FSN Alter Key")).Value;
        IF DeliveryOrder_l."FSN Alter Key" = 0 THEN
            EXIT(' ');

        DelStreet_l.RESET;
        DelStreet_l.SETRANGE(DelStreet_l."FSN Alter Key", DeliveryOrder_l."FSN Alter Key");
        IF DelStreet_l.FINDFIRST THEN
            EXIT(DelSuggestStoreText(DelStreet_l, 4)); /*4 = All suggest*/
        EXIT(' ');

    end;

    procedure DelStreetDriverDistanceAPI(pDeliveryStreet: Record "LSC Delivery Street")
    var
        StoreLinksSET: Record "FSN Store Link";
        Parameters: Record "FSN Parameter";
        DeliveryStoreLink: Codeunit "FSN Delivery Store Link";
        RequestString: Text;
        StringStoreCallCenter: Text;
        StringStoreCCAlternative: Text;
        i: Integer;
        NewStoreRestaurant: Code[10];
        ChangeType: Boolean;
        AddressUrlLocal: Text;
    begin
        if not Parameters.Get('DAF', 'MATRIXAPI') or
            (Parameters."Web Uri" = '') or
            (Parameters.Valor = '') or
            not (Parameters."Value Text 1" in ['walking', 'driver']) then //mode
            exit;

        IF Parameters.Valor = 'EXIT()' THEN //Not use API
            EXIT;

        CLEAR(ChangeType);

        StoreLinksSET.RESET;
        StoreLinksSET.SETRANGE(StoreLinksSET.Type, StoreLinksSET.Type::StreetAlterKey);
        StoreLinksSET.SETRANGE(StoreLinksSET."Parent Code", pDeliveryStreet."FSN Alter Key Text");
        StoreLinksSET.SETFILTER(StoreLinksSET."Store No.", '<>%1', '');
        StoreLinksSET.SETFILTER(StoreLinksSET."Km Between Points", '<=%1', pDeliveryStreet."FSN Distance Show Km.");
        IF StoreLinksSET.FIND('-') THEN
            REPEAT
                IF (StoreLinksSET."Parent Latitude" <> 0) AND
                  (StoreLinksSET."Parent Longitude" <> 0) AND
                  (StoreLinksSET.Latitude <> 0) AND
                  (StoreLinksSET.Longitude <> 0) AND
                  (StoreLinksSET."Km Distance Driver" = 0) THEN BEGIN

                    AddressUrlLocal :=
                      'https://maps.googleapis.com/maps/api/distancematrix/json?units=metric&origins=' +
                          FORMAT(StoreLinksSET.Latitude, 0, '<Precision,10:10><Standard format,0>') + ',' +
                          FORMAT(StoreLinksSET.Longitude, 0, '<Precision,10:10><Standard format,0>') +
                        '&destinations=' +
                          FORMAT(StoreLinksSET."Parent Latitude", 0, '<Precision,10:10><Standard format,0>') + ',' +
                          FORMAT(StoreLinksSET."Parent Longitude", 0, '<Precision,10:10><Standard format,0>') +
                        '&mode=' + Parameters."Value Text 1" +  //walking,driver
                        '&key=' + Parameters.Valor;

                    COMMIT;

                    Clear(POSMenuLIneTmp);
                    POSMenuLIneTmp.Command := 'MATRIX_API';
                    Clear(DeliveryStoreLink);
                    DeliveryStoreLink.ClearGlobals();
                    DeliveryStoreLink.SetParameters(AddressUrlLocal, StoreLinksSET);
                    if DeliveryStoreLink.Run(POSMenuLIneTmp) then begin
                        Parameters."Port 2" += 1;
                        ChangeType := TRUE;
                    end;
                END ELSE
                    IF StoreLinksSET."Km Distance Driver" > 0 THEN
                        ChangeType := TRUE;
            UNTIL StoreLinksSET.NEXT = 0;

        if ChangeType then
            Parameters.Modify();

        i := 1;
        CLEAR(NewStoreRestaurant);
        CLEAR(StringStoreCallCenter);
        CLEAR(StringStoreCCAlternative);

        StoreLinksSET.RESET;
        IF pDeliveryStreet."FSN Distance Order Type" <> pDeliveryStreet."FSN Distance Order Type"::"Distance Plane" THEN
            StoreLinksSET.SETCURRENTKEY("Km Distance Driver")
        ELSE
            StoreLinksSET.SETCURRENTKEY("Km Between Points");

        StoreLinksSET.SETRANGE(StoreLinksSET.Type, StoreLinksSET.Type::StreetAlterKey);
        StoreLinksSET.SETRANGE(StoreLinksSET."Parent Code", pDeliveryStreet."FSN Alter Key Text");
        StoreLinksSET.SETFILTER(StoreLinksSET."Store No.", '<>%1', '');

        IF pDeliveryStreet."FSN Distance Order Type" <> pDeliveryStreet."FSN Distance Order Type"::"Distance Plane" THEN
            StoreLinksSET.SETFILTER(StoreLinksSET."Km Distance Driver", '>0&<=%1', pDeliveryStreet."FSN Distance Show Km.")
        ELSE
            StoreLinksSET.SETFILTER(StoreLinksSET."Km Between Points", '>0&<=%1', pDeliveryStreet."FSN Distance Show Km.");

        IF StoreLinksSET.FIND('-') THEN
            REPEAT
                IF (NewStoreRestaurant = '') AND (StoreLinksSET."Link Type" IN [StoreLinksSET."Link Type"::DeliveryStoreSuper,
                                                                              StoreLinksSET."Link Type"::DeliveryStore]) THEN
                    NewStoreRestaurant := StoreLinksSET."Store No.";

                IF StoreLinksSET."Link Type" IN//DeliveryStoreSuper,DeliveryStore,DeliveryAlternative,NormalStore,None
                  [StoreLinksSET."Link Type"::DeliveryStoreSuper, StoreLinksSET."Link Type"::DeliveryStore] THEN BEGIN
                    StringStoreCallCenter += StoreLinksSET."Store No." + '-';
                END ELSE BEGIN
                    StringStoreCCAlternative += StoreLinksSET."Store No." + '-';
                END;
                i += 1;
            UNTIL StoreLinksSET.NEXT = 0;

        IF NewStoreRestaurant = '' THEN
            NewStoreRestaurant := pDeliveryStreet."Restaurant No.";

        IF StringStoreCallCenter = '' THEN BEGIN
            IF NewStoreRestaurant <> '' THEN
                StringStoreCallCenter := NewStoreRestaurant;
        END ELSE BEGIN
            StringStoreCallCenter := COPYSTR(StringStoreCallCenter, 1, STRLEN(StringStoreCallCenter) - 1);

            IF STRPOS(StringStoreCallCenter, '-') > 0 THEN
                NewStoreRestaurant := COPYSTR(StringStoreCallCenter, 1, STRPOS(StringStoreCallCenter, '-') - 1);
        END;

        IF StringStoreCCAlternative = '' THEN
            StringStoreCCAlternative := NewStoreRestaurant
        ELSE BEGIN
            StringStoreCCAlternative := COPYSTR(StringStoreCCAlternative, 1, STRLEN(StringStoreCCAlternative) - 1);
        END;

        IF NewStoreRestaurant <> '' THEN
            pDeliveryStreet."Restaurant No." := NewStoreRestaurant;

        IF ChangeType THEN
            pDeliveryStreet."FSN Distance Order Type" := pDeliveryStreet."FSN Distance Order Type"::"Distance Driver";

        pDeliveryStreet."FSN Stores Suggest" := COPYSTR(StringStoreCallCenter, 1, 100);
        pDeliveryStreet."FSN Stores Complement" := COPYSTR(StringStoreCCAlternative, 1, 100);
        pDeliveryStreet.MODIFY(TRUE);
    end;

    procedure GetDistanceMatrixJson(): Boolean
    var
        Address: Text[250];
        HttpWebRequest: DotNet HttpWebRequest;
        HttpWebResponse: DotNet HttpWebResponse;
        StreamReader: DotNet StreamReader;
        BodyText: Text;
        JSonConvert: DotNet JsonConvert;
        JArray: DotNet JArray;
        JObject: DotNet JObject;
        JToken: DotNet JToken;
        JValue: DotNet JValue;
        Km: Decimal;
        Seconds: Decimal;
        StoreLinkModify: Record "FSN Store Link";
        OdataInterface: Codeunit "FSN OData Conexion";
    begin

        Address := GlobalUrl;
        HttpWebRequest := HttpWebRequest.HttpWebRequest();
        HttpWebRequest := HttpWebRequest.Create(Address);
        HttpWebRequest.Timeout(10000);
        HttpWebRequest.Method('GET');
        HttpWebRequest.ContentType('application/json');

        HttpWebResponse := HttpWebResponse.HttpWebResponse();
        HttpWebResponse := HttpWebRequest.GetResponse();
        StreamReader := StreamReader.StreamReader(HttpWebResponse.GetResponseStream());
        BodyText := StreamReader.ReadToEnd();

        /*
        //Example

        BodyText :=
        '{' +
           '"destination_addresses" : [ "New York, NY, USA" ],' +
           '"origin_addresses" : [ "Washington, DC, USA" ],' +
           '"rows" : [' +
              '{' +
                 '"elements" : [' +
                    '{' +
                       '"distance" : {' +
                          '"text" : "225 mi",' +
                          '"value" : 361715' +
                       '},' +
                       '"duration" : {' +
                          '"text" : "3 hours 49 mins",' +
                          '"value" : 13725' +
                       '},' +
                       '"status" : "OK"' +
                    '}' +
                 ']' +
              '}' +
           '],' +
           '"status" : "OK"' +
        '}';
        */
        IF BodyText = '' then
            EXIT;

        JObject := JObject.Parse(BodyText);
        JArray := JObject.SelectToken('rows');

        IF JArray.HasValues THEN BEGIN
            JObject := JArray.First;
            JArray := JObject.SelectToken('elements');

            IF JArray.HasValues THEN BEGIN
                JObject := JArray.First;
                IF OdataInterface.GetValueAsText(JObject, 'status') = 'OK' THEN BEGIN
                    JToken := JObject.SelectToken('distance');
                    IF NOT ISNULL(JToken) THEN
                        Km := OdataInterface.GetValueAsDecimal(JToken, 'value');

                    JToken := JObject.SelectToken('duration');
                    IF NOT ISNULL(JToken) THEN
                        Seconds := OdataInterface.GetValueAsDecimal(JToken, 'value');

                    IF StoreLinkModify.Get(GlobalRec.Type, GlobalRec."Parent Code", GlobalRec."Link Type", GlobalRec."Store No.") then begin
                        StoreLinkModify."Km Distance Driver" := ROUND(Km / 1000, 0.01, '=');
                        StoreLinkModify."Time Driver Min." := ROUND(Seconds / 60, 0.01, '=');
                        StoreLinkModify.MODIFY;
                    END;
                END;
            END;
        END;

    end;

    procedure SetParameters(pAddresUrl: Text; pRec: Record "FSN Store Link")
    begin
        GlobalUrl := pAddresUrl;
        GlobalRec := pRec;

    end;

    procedure ClearGlobals()
    begin
        Clear(GlobalUrl);
        GlobalRec.Reset();
        Clear(GlobalRec);
    end;

    procedure CheckAlterKey(var Rec1: Record "LSC Delivery Street")
    var
        DeliveryStreet1: Record "LSC Delivery Street";
        FSNUtility: Codeunit "FSN Utility";
    begin
        if Rec1."FSN Alter Key" = 0 then begin
            DeliveryStreet1.Reset();
            DeliveryStreet1.SetCurrentKey("FSN Alter Key");
            if DeliveryStreet1.FindLast() then
                Rec1."FSN Alter Key" := DeliveryStreet1."FSN Alter Key" + 1
            else
                Rec1."FSN Alter Key" := 1;
            Rec1."FSN Alter Key Text" := FSNUtility.ZeroPad(Format(Rec1."FSN Alter Key"), 9);

        end;
    end;
    //Events
    [EventSubscriber(ObjectType::Table, Database::"LSC Delivery Street", 'OnBeforeInsertEvent', '', true, true)]
    local procedure "Delivery Street_OnBeforeInsertEvent"
    (
        var Rec: Record "LSC Delivery Street";
        RunTrigger: Boolean
    )
    begin
        CheckAlterKey(Rec);
        Rec."Number from" := 1;
        Rec."Number to" := 1;
    end;

    [EventSubscriber(ObjectType::Table, Database::"LSC Delivery Street", 'OnBeforeModifyEvent', '', true, true)]
    local procedure "Delivery Street_OnBeforeModifyEvent"
    (
        var Rec: Record "LSC Delivery Street";
        var xRec: Record "LSC Delivery Street";
        RunTrigger: Boolean
    )
    begin
        CheckAlterKey(Rec);
        Rec."Number from" := 1;
        Rec."Number to" := 1;
    end;


    [EventSubscriber(ObjectType::Table, Database::"LSC Delivery Street", 'OnBeforeDeleteEvent', '', true, true)]
    local procedure "Delivery Street_OnBeforeDeleteEvent"
    (
        var Rec: Record "LSC Delivery Street";
        RunTrigger: Boolean
    )
    var
        FSNStoreLink1: Record "FSN Store Link";
    begin
        FSNStoreLink1.Reset();
        FSNStoreLink1.SetRange(FSNStoreLink1.Type, FSNStoreLink1.Type::StreetAlterKey);
        FSNStoreLink1.SetRange(FSNStoreLink1."Parent Code", Rec."FSN Alter Key Text");
        FSNStoreLink1.DeleteAll();
    end;

}
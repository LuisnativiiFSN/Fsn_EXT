codeunit 50046 "FSN self-Mgmt Offer"
{
    TableNo = 99001586;

    trigger OnRun();
    begin
        gCommand := Rec.Code;
        Case gCommand of
            'PUSH_OFFERS':
                PushOffers;
        End;
    end;

    var
        gCommand: Code[20];
        SelfOffers: Record "FSN Self-Mgmt Offers";
        PerDiscLine: Record "LSC Periodic Discount Line";
        gGroupType: Code[20];
        gCustDiscGroup: Code[20];
        OfferNo: Code[20];
        Type: Option;
        pagina: Page "LSC Retail Item Card";
        POSTranCod: Codeunit "LSC POS Transaction";
        POSSESSION: Codeunit "LSC POS Session";
        Parametro: Record "FSN Parameter";

    procedure PushOffers()
    begin
        SelfOffers.Reset();
        if SelfOffers.Find('-') then
            repeat
                SelectGroupType(gGroupType, SelfOffers);
                SelectDiscGroup(gCustDiscGroup, SelfOffers);
                OfferNo := gGroupType + gCustDiscGroup;
                CheckFunction();
            until SelfOffers.Next() = 0;
    end;

    procedure DeleteOffer(var SOffer_L: Record "FSN Self-Mgmt Offers"; OfferNo: Code[20]; Origin: Boolean)
    begin
        PerDiscLine.Reset();
        PerDiscLine.SetCurrentKey("Offer No.", "Line No.");
        PerDiscLine.SetRange("Offer No.", OfferNo);
        PerDiscLine.SetRange("No.", SOffer_L."Item No.");
        PerDiscLine.SetRange("Unit of Measure", SOffer_L."Unit of Measure");
        if PerDiscLine.FindFirst() then begin
            PerDiscLine.Delete(false);
            PerDiscLine.CreateActions(2);
        end;

        if Origin then
            SOffer_L.Delete(true);
    end;

    procedure ModifyOffer(var Handled: Boolean)
    begin
        PerDiscLine.Reset();
        PerDiscLine.SetCurrentKey("Offer No.", "Line No.");
        PerDiscLine.SetRange("Offer No.", OfferNo);
        PerDiscLine.SetRange("No.", SelfOffers."Item No.");
        PerDiscLine.SetRange("Unit of Measure", SelfOffers."Unit of Measure");
        if PerDiscLine.FindFirst() then begin
            PerDiscLine.Validate("Deal Price/Disc. %", SelfOffers."% discount");
            /*
            ** Bloque para colocar el sell Out
            */
            PerDiscLine.Modify(false);
            PerDiscLine.CreateActions(1);
            Handled := true;
        end;
    end;

    procedure InsertOffer()
    var
        Handled: Boolean;
        LastNo: Integer;
    begin
        ModifyOffer(Handled);

        if Handled then
            exit;

        LastNo := GetLastNo();
        GetType();
        PerDiscLine.Init();
        PerDiscLine."Offer No." := OfferNo;
        PerDiscLine."Line No." := LastNo;
        PerDiscLine.Type := Type;
        PerDiscLine.Validate("No.", SelfOffers."Item No.");
        perDiscLine.Validate("Deal Price/Disc. %", SelfOffers."% discount");
        if SelfOffers."Unit of Measure" <> '' then
            PerDiscLine.Validate("Unit of Measure", SelfOffers."Unit of Measure");
        PerDiscLine.Validate("Price Group", SelfOffers.Store);
        /*
        ** bloque para colocar el sell out
        */
        PerDiscLine.Insert(false);
        PerDiscLine.CreateActions(0);
    end;

    procedure CheckFunction()
    begin
        if (SelfOffers."End Date" <> 0D) then
            if (SelfOffers."End Date" + 1 = Today) then
                DeleteOffer(SelfOffers, OfferNo, true);

        if (SelfOffers."Start Date" = Today) then
            InsertOffer();
    end;

    procedure SelectGroupType(var GroupType: Code[20]; SelfOffer: Record "FSN Self-Mgmt Offers")
    begin
        case SelfOffer."Offer Type" of
            SelfOffer."Offer Type"::Banks:
                begin
                    case SelfOffer."Bank name" of
                        SelfOffer."Bank name"::Agricola:
                            GroupType := 'AGRICOLA_';
                        Selfoffer."Bank name"::Cuscatlan:
                            GroupType := 'CUSCATLAN_';
                        Selfoffer."Bank name"::Promerica:
                            GroupType := 'PROMERICA_';
                        Selfoffer."Bank name"::Credisiman:
                            GroupType := 'CREDISIMAN_';
                        Selfoffer."Bank name"::Bac:
                            GroupType := 'BAC_';
                        Selfoffer."Bank name"::Credicomer:
                            GroupType := 'CREDICOMER_';
                        Selfoffer."Bank name"::Fedecredito:
                            GroupType := 'FEDECREDITO_';
                        Selfoffer."Bank name"::Hipotecario:
                            GroupType := 'HIPOTECARIO_';
                    end;
                end;
            Selfoffer."Offer Type"::"Special Group":
                GroupType := 'ESPECIAL_';
            Selfoffer."Offer Type"::Base:
                GroupType := 'OFERTERO_';
        end;
    end;

    procedure SelectDiscGroup(var DiscGroup: Code[20]; SelfOffer: Record "FSN Self-Mgmt Offers")
    begin
        case SelfOffer."discount Group" of
            SelfOffer."discount Group"::Retail:
                DiscGroup := 'RET';
            SelfOffer."discount Group"::VIP:
                DiscGroup := 'VIP';
            SelfOffer."discount Group"::ADFSN:
                DiscGroup := 'ADF';
            SelfOffer."discount Group"::FASANI:
                DiscGroup := 'FSN';
        end;
    end;

    procedure GetLastNo() LastNo: Integer
    begin
        PerDiscLine.Reset();
        PerDiscLine.SetCurrentKey("Offer No.", "Line No.");
        PerDiscLine.SetRange(PerDiscLine."Offer No.", OfferNo);
        if PerDiscLine.FindLast() then
            LastNo := PerDiscLine."Line No." + 1000;
        exit(LastNo);
    end;

    procedure GetType()
    begin
        case SelfOffers.Type of
            SelfOffers.Type::Item:
                Type := PerDiscLine.Type::Item;
            SelfOffers.Type::"Special Group":
                Type := PerDiscLine.Type::"Special Group";
            SelfOffers.Type::All:
                Type := PerDiscLine.Type::All;
        end;
    end;

    /////////////////////////////////////////Max Quantity Offer/////////////////////////////////////////////

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Transaction Events", 'OnBeforeTotalExecuted', '', true, true)]
    local procedure "LSC POS Transaction Events_OnBeforeTotalExecuted"
    (
     var POSTransaction: Record "LSC POS Transaction";
     var IsHandled: Boolean
    )
    var
        LSCPeriodicType: Record "LSC POS Trans. Per. Disc. Type";
        LSCPOSTransLine: Record "LSC POS Trans. Line";
        PeriodicDiscont: Record "LSC Periodic Discount";
        Text000: Label 'La cantidad máxima del producto %1 a facturar para el cliente es %2 cajas';
        Text002: Label 'Se ha superado la cantidad máxima de compra por dia del producto %1. El límite permitido para facturar al cliente es de %2 cajas';
        LongText: Integer;
        MText: Integer;
        LongText2: Integer;
        CantCaja: Integer;
        CantText: Text;
        CanTotal: Decimal;
        PosTransline: Record "LSC POS Trans. Line";
        Cant: Decimal;
        Logm: Integer;
        ItemStatus: Record "LSC Item Status";
        ItemStatusLink: Record "LSC Item Status Link";
        item: Record Item;
        CustomerL: Record Customer;
    begin

        if not IsHandled then begin
            IF NOT POSTransaction."Sale Is Return Sale" THEN BEGIN
                if ValidateClientGeneral(POSTransaction) then
                    IsHandled := true;
            end;
        end;

        if not IsHandled then begin
            IF NOT POSTransaction."Sale Is Return Sale" THEN BEGIN
                LSCPOSTransLine.Reset();
                LSCPOSTransLine.SetRange("Receipt No.", POSTransaction."Receipt No.");
                LSCPOSTransLine.SetRange("Entry Status", PosTransline."Entry Status"::" ");
                LSCPOSTransLine.SetRange("Entry Type", LSCPOSTransLine."Entry Type"::Item);
                IF LSCPOSTransLine.Find('-') then begin
                    repeat
                        Parametro.Reset();
                        Parametro.SetRange(Grupo, 'MAXIMOF');
                        Parametro.SetRange(Codigo, 'MAXFAC');
                        IF Parametro.FindFirst() then
                            IF Parametro.Activo then begin
                                if Item.Get(LSCPOSTransLine.Number) then
                                    LongText := StrLen(Item."Base Unit of Measure");

                                if not (LSCPOSTransLine."Unit of Measure" = Item."Purch. Unit of Measure") then
                                    if LongText > 8 then begin
                                        Logm := LongText - 8;
                                        LongText := LongText - Logm;
                                    end;

                                if (Item."Base Unit of Measure" = Item."Purch. Unit of Measure") OR (LSCPOSTransLine."Unit of Measure" = Item."Purch. Unit of Measure") then begin
                                    if LSCPOSTransLine."Unit of Measure" = '' then
                                        LSCPOSTransLine."Unit of Measure" := Item."Base Unit of Measure";
                                    CanTotal := LSCPOSTransLine.Quantity;
                                end else begin
                                    LongText2 := StrLen(Item."Purch. Unit of Measure");
                                    CantText := CopyStr(Item."Purch. Unit of Measure", LongText, LongText2);
                                    Evaluate(CantCaja, CantText);
                                    CanTotal := LSCPOSTransLine.Quantity / CantCaja;
                                end;

                                PosTransline.Reset();
                                PosTransline.SetRange("Entry Type", PosTransline."Entry Type"::Item);
                                PosTransline.SetRange("Receipt No.", LSCPOSTransLine."Receipt No.");
                                PosTransline.SetRange("Entry Status", PosTransline."Entry Status"::" ");
                                PosTransline.SetRange(Number, LSCPOSTransLine.Number);
                                if PosTransline.Find('-') then begin
                                    repeat
                                        if PosTransline."Unit of Measure" <> '' then
                                            if LSCPOSTransLine."Unit of Measure" <> PosTransline."Unit of Measure" then begin
                                                if PosTransline."Unit of Measure" <> item."Base Unit of Measure" then begin
                                                    CanTotal := CanTotal + PosTransline.Quantity;
                                                end else begin
                                                    LongText2 := StrLen(Item."Purch. Unit of Measure");
                                                    CantText := CopyStr(Item."Purch. Unit of Measure", LongText, LongText2);
                                                    Evaluate(CantCaja, CantText);
                                                    Cant := PosTransline.Quantity / CantCaja;
                                                    CanTotal := CanTotal + Cant;
                                                end;
                                            end;
                                    until PosTransline.Next() = 0;
                                end;

                                ItemStatusLink.Reset();
                                ItemStatusLink.SetRange("Item No.", LSCPOSTransLine.Number);
                                if ItemStatusLink.Find('-') then begin
                                    ItemStatus.Reset();
                                    if ItemStatus.Get(ItemStatusLink."Status Code") then begin
                                        if ItemStatusLink."FSN Maximum billing" <> 0 then begin
                                            if CanTotal > ItemStatusLink."FSN Maximum billing" then begin
                                                if CustomerL.get(POSTransaction."Customer No.") then
                                                    IF (not CustomerL."FSN Insurer") and (not CustomerL."FSN Request Beneficiary") and (not POSTransaction."FSN Remission No.") THEN BEGIN
                                                        Error(Text000, LSCPOSTransLine.Number, ItemStatusLink."FSN Maximum billing");
                                                        IsHandled := true;
                                                    end;
                                            end else begin
                                                if CustomerL.get(POSTransaction."Customer No.") then begin//250725
                                                    if LSCPOSTransLine."Unit of Measure" <> '' then begin
                                                        ValidatePurchaseForBlocking(CustomerL."No.", LSCPOSTransLine.Number, LSCPOSTransLine."Unit of Measure", CanTotal);

                                                        if CanTotal > ItemStatusLink."FSN Maximum billing" then
                                                            IF (not CustomerL."FSN Insurer") and (not CustomerL."FSN Request Beneficiary") and (not POSTransaction."FSN Remission No.") THEN BEGIN
                                                                Error(Text002, LSCPOSTransLine.Number, ItemStatusLink."FSN Maximum billing");
                                                                IsHandled := true;
                                                            end;
                                                    end;
                                                end;
                                            end;
                                        end else begin
                                            if ItemStatus."FSN Maximum billing" <> 0 then begin
                                                if CanTotal > ItemStatus."FSN Maximum billing" then begin
                                                    if CustomerL.get(POSTransaction."Customer No.") then
                                                        IF (not CustomerL."FSN Insurer") and (not CustomerL."FSN Request Beneficiary") and (not POSTransaction."FSN Remission No.") THEN BEGIN
                                                            Error(Text000, LSCPOSTransLine.Number, ItemStatus."FSN Maximum billing");
                                                            IsHandled := true;
                                                        end;
                                                end else begin
                                                    if CustomerL.get(POSTransaction."Customer No.") then begin//250725
                                                        if LSCPOSTransLine."Unit of Measure" <> '' then begin
                                                            ValidatePurchaseForBlocking(CustomerL."No.", LSCPOSTransLine.Number, LSCPOSTransLine."Unit of Measure", CanTotal);

                                                            if CanTotal > ItemStatusLink."FSN Maximum billing" then
                                                                IF (not CustomerL."FSN Insurer") and (not CustomerL."FSN Request Beneficiary") and (not POSTransaction."FSN Remission No.") THEN BEGIN
                                                                    Error(Text002, LSCPOSTransLine.Number, LSCPOSTransLine."Unit of Measure", ItemStatusLink."FSN Maximum billing");
                                                                    IsHandled := true;
                                                                end;
                                                        end;
                                                    end;
                                                end;
                                            end;
                                        end;
                                    end;
                                end;
                            end;

                        LSCPeriodicType.Reset();
                        LSCPeriodicType.SetRange("Receipt No.", LSCPOSTransLine."Receipt No.");//140725
                        LSCPeriodicType.SetRange("Line No.", LSCPOSTransLine."Line No.");
                        LSCPeriodicType.SetRange("Periodic Disc. Type", LSCPeriodicType."Periodic Disc. Type"::"Disc. Offer");
                        if LSCPeriodicType.FindFirst() then begin
                            if PeriodicDiscont.Get(LSCPeriodicType."Offer No.") then
                                if PeriodicDiscont."FSN Max. para Facturar" <> 0 then begin
                                    IF LSCPOSTransLine.Quantity > PeriodicDiscont."FSN Max. para Facturar" then begin
                                        Error(StrSubstNo(Text000, LSCPOSTransLine.Number, PeriodicDiscont."FSN Max. para Facturar"));
                                        IsHandled := true;
                                    end;
                                end;
                        end;
                    until LSCPOSTransLine.Next() = 0;
                end;
            end;
        END;

        //Valida maximo de descuento y maximo de monto con cupones de ofertas
        if not IsHandled then begin
            LSCPOSTransLine.Reset();
            LSCPOSTransLine.SetRange("Receipt No.", POSTransaction."Receipt No.");
            LSCPOSTransLine.SetRange(LSCPOSTransLine."Entry Type", LSCPOSTransLine."Entry Type"::Coupon);
            LSCPOSTransLine.SetRange(LSCPOSTransLine."Entry Status", LSCPOSTransLine."Entry Status"::" ");
            if LSCPOSTransLine.Find('-') then begin
                repeat
                    IsHandled := ValCouponTotalPress(LSCPOSTransLine."Coupon Code", LSCPOSTransLine."Receipt No.");
                until LSCPOSTransLine.Next() = 0;
            end;
        end;
    end;

    procedure ValidateClientGeneral(POSTransaction: Record "LSC POS Transaction"): Boolean
    var
        Customer_l: Record Customer;
        _COMODIN: Label 'COMODIN';
        lText001: Label 'El grupo descuento cliente COMODIN no puede ser VIP';
    begin
        IF POSTransaction."Customer No." <> 'V1' THEN
            if Customer_l.get(POSTransaction."Customer No.") then begin
                IF Customer_l."LSC Retail Customer Group" = _COMODIN THEN
                    IF Customer_l."Customer Disc. Group" = 'VIP' then begin
                        Error(lText001);
                        exit(true);
                    end;
            end;
        exit(false);
    end;

    //se valida si hay compras 
    procedure ValidatePurchaseForBlocking(CustomerNo: Code[20]; ItemNo: Code[20]; UnitofMeasure: Code[10]; var CanTotal: Decimal)
    var
        TransactionHeader: Record "LSC Transaction Header";
        TransSalesEntry: Record "LSC Trans. Sales Entry";
        item: Record Item;
        LongText2: Integer;
        CantCaja: Integer;
        CantText: Text;
        LongText: Integer;
        Cant: Decimal;
        Logm: Integer;
        CantTotal: Decimal;
    begin
        TransactionHeader.Reset();
        TransactionHeader.SetRange(Date, Today);
        TransactionHeader.SetRange(TransactionHeader."Customer No.", CustomerNo);
        TransactionHeader.SetRange(TransactionHeader."Refund Receipt No.", '');
        TransactionHeader.SetRange(TransactionHeader."Retrieved from Receipt No.", '');
        if TransactionHeader.Find('-') then begin
            if Item.Get(ItemNo) then
                LongText := StrLen(Item."Base Unit of Measure");

            if not (UnitofMeasure = Item."Purch. Unit of Measure") then
                if LongText > 8 then begin
                    Logm := LongText - 8;
                    LongText := LongText - Logm;
                end;

            repeat
                TransSalesEntry.SetCurrentKey("Store No.", "POS Terminal No.", "Transaction No.");
                TransSalesEntry.SetRange(TransSalesEntry."Store No.", TransactionHeader."Store No.");
                TransSalesEntry.SetRange(TransSalesEntry."POS Terminal No.", TransactionHeader."POS Terminal No.");
                TransSalesEntry.SetRange(TransSalesEntry."Transaction No.", TransactionHeader."Transaction No.");
                TransSalesEntry.SetRange(TransSalesEntry."Item No.", ItemNo);
                if TransSalesEntry.find('-') then begin
                    repeat
                        if TransSalesEntry."Unit of Measure" <> '' then begin
                            if (TransSalesEntry."Unit of Measure" <> item."Base Unit of Measure")
                                and (TransSalesEntry."Unit of Measure" = Item."Purch. Unit of Measure") then
                                CanTotal := CanTotal + ABS(TransSalesEntry."UOM Quantity");

                            IF (TransSalesEntry."Unit of Measure" = item."Base Unit of Measure")
                                and (TransSalesEntry."Unit of Measure" = Item."Purch. Unit of Measure") then
                                CanTotal := CanTotal + ABS(TransSalesEntry."Quantity");

                            IF (TransSalesEntry."Unit of Measure" = item."Base Unit of Measure")
                                 and (TransSalesEntry."Unit of Measure" <> Item."Purch. Unit of Measure") then begin
                                LongText2 := StrLen(Item."Purch. Unit of Measure");
                                CantText := CopyStr(Item."Purch. Unit of Measure", LongText, LongText2);
                                if Evaluate(CantCaja, CantText) then;
                                if CantCaja <> 0 then
                                    Cant := ABS(TransSalesEntry.Quantity) / CantCaja
                                else
                                    exit;
                                CanTotal := CanTotal + Cant;
                            end;
                        END;
                    until TransSalesEntry.Next() = 0;
                end;
            until TransactionHeader.Next() = 0;
        end;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"FSN Utility", 'OnInvokeGlobalChannelEvent', '', true, true)]
    local procedure "FSN Utility_OnInvokeGlobalChannelEvent"
    (
    var XMLRequest: Text;
    var XMLResponse: Text;
    var RequestID: Text[50];
    var POSMenuLine: Record "LSC POS Menu Line";
    var Processed: Boolean;
    var MsgResult: Text
    )
    var
        RetailSetup: Record "LSC Retail Setup";
        ItemStatusLink: Record "LSC Item Status Link";
    begin

        if RequestID = 'FSNBLOCKITEM' then begin
            if POSMenuLine."POS Help ID" <> '' then
                ProcessVaBloqItem(XMLResponse, POSMenuLine.Command, POSMenuLine."POS Help ID", POSMenuLine."Current-Price", POSMenuLine."Post Command", Processed, MsgResult);
        end;


        if RequestID = 'ITEMMARGEN' then begin
            ItemStatusLink.Reset();
            ItemStatusLink.SetRange("Item No.", XMLRequest);
            if ItemStatusLink.FindFirst() then
                if ItemStatusLink."FSN Maximum billing" <> 0 then
                    Processed := true
                else
                    Processed := false;
        end;
    end;

    //Proceso para prefactura
    procedure ProcessVaBloqItem(Receipt: text; Number: Code[20]; UnitofMeasure: Code[10]; Quantity: Decimal; CustomerNo: Code[20]; FSNRemissionNo: Boolean; var MessageText: Text)
    var
        Item: Record Item;
        LongText: Integer;
        MText: Integer;
        LongText2: Integer;
        CantCaja: Integer;
        CantText: Text;
        CanTotal: Decimal;
        Cant: Decimal;
        Logm: Integer;
        ItemStatus: Record "LSC Item Status";
        ItemStatusLink: Record "LSC Item Status Link";
        CustomerL: Record Customer;
        PosTransline: Record "LSC POS Trans. Line";
        Text000: Label 'La cantidad máxima del producto %1 a facturar para el cliente es %2 cajas';
        Text002: Label 'Se ha superado la cantidad máxima de compra por dia del producto %1. El límite permitido para facturar al cliente es de %2 cajas';
    begin
        Parametro.Reset();//180725
        Parametro.SetRange(Grupo, 'MAXIMOF');
        Parametro.SetRange(Codigo, 'MAXFAC');
        IF Parametro.FindFirst() then
            IF Parametro.Activo then begin
                if Item.Get(Number) then
                    LongText := StrLen(Item."Base Unit of Measure");

                if not (UnitofMeasure = Item."Purch. Unit of Measure") then
                    if LongText > 8 then begin
                        Logm := LongText - 8;
                        LongText := LongText - Logm;
                    end;

                if (Item."Base Unit of Measure" = Item."Purch. Unit of Measure") OR (UnitofMeasure = Item."Purch. Unit of Measure") then begin
                    if UnitofMeasure = '' then
                        UnitofMeasure := Item."Base Unit of Measure";
                    CanTotal := Quantity;
                end else begin
                    LongText2 := StrLen(Item."Purch. Unit of Measure");
                    CantText := CopyStr(Item."Purch. Unit of Measure", LongText, LongText2);
                    Evaluate(CantCaja, CantText);
                    if CantCaja <> 0 then
                        CanTotal := Quantity / CantCaja
                    else
                        exit;
                end;

                PosTransline.Reset();
                PosTransline.SetRange("Entry Type", PosTransline."Entry Type"::Item);
                PosTransline.SetRange("Receipt No.", Receipt);
                PosTransline.SetRange("Entry Status", PosTransline."Entry Status"::" ");
                PosTransline.SetRange(Number, Number);
                if PosTransline.Find('-') then begin
                    repeat
                        if PosTransline."Unit of Measure" <> '' then
                            if UnitofMeasure <> PosTransline."Unit of Measure" then begin
                                if PosTransline."Unit of Measure" <> item."Base Unit of Measure" then begin
                                    CanTotal := CanTotal + PosTransline.Quantity;
                                end else begin
                                    LongText2 := StrLen(Item."Purch. Unit of Measure");
                                    CantText := CopyStr(Item."Purch. Unit of Measure", LongText, LongText2);
                                    Evaluate(CantCaja, CantText);
                                    if CantCaja <> 0 then begin
                                        Cant := PosTransline.Quantity / CantCaja;
                                        CanTotal := CanTotal + Cant;
                                    end else
                                        exit;
                                end;
                            end;
                    until PosTransline.Next() = 0;
                end;

                ItemStatusLink.Reset();
                ItemStatusLink.SetRange("Item No.", Number);
                if ItemStatusLink.Find('-') then begin
                    ItemStatus.Reset();
                    if ItemStatus.Get(ItemStatusLink."Status Code") then begin
                        if ItemStatusLink."FSN Maximum billing" <> 0 then begin
                            if CanTotal > ItemStatusLink."FSN Maximum billing" then begin
                                if CustomerL.get(CustomerNo) then
                                    IF (not CustomerL."FSN Insurer") and (not CustomerL."FSN Request Beneficiary") and (not FSNRemissionNo) THEN BEGIN
                                        MessageText := StrSubstNo(Text000, Number, ItemStatusLink."FSN Maximum billing")
                                    end;
                            end else begin
                                if CustomerL.get(CustomerNo) then begin//250725
                                    if UnitofMeasure <> '' then begin
                                        ValidatePurchaseForBlocking(CustomerL."No.", Number, UnitofMeasure, CanTotal);

                                        if CanTotal > ItemStatusLink."FSN Maximum billing" then
                                            IF (not CustomerL."FSN Insurer") and (not CustomerL."FSN Request Beneficiary") and (not FSNRemissionNo) THEN BEGIN
                                                MessageText := StrSubstNo(Text002, Number, ItemStatusLink."FSN Maximum billing")
                                            end;
                                    end;
                                end;
                            end;
                        end else begin
                            if ItemStatus."FSN Maximum billing" <> 0 then begin
                                if CanTotal > ItemStatus."FSN Maximum billing" then begin
                                    if CustomerL.get(CustomerNo) then
                                        IF (not CustomerL."FSN Insurer") and (not CustomerL."FSN Request Beneficiary") and (not FSNRemissionNo) THEN BEGIN
                                            MessageText := StrSubstNo(Text000, Number, ItemStatus."FSN Maximum billing");
                                        end;
                                end else begin
                                    if CustomerL.get(CustomerNo) then begin//250725
                                        if UnitofMeasure <> '' then begin
                                            ValidatePurchaseForBlocking(CustomerL."No.", Number, UnitofMeasure, CanTotal);

                                            if CanTotal > ItemStatusLink."FSN Maximum billing" then
                                                IF (not CustomerL."FSN Insurer") and (not CustomerL."FSN Request Beneficiary") and (not FSNRemissionNo) THEN BEGIN
                                                    MessageText := StrSubstNo(Text002, Number, ItemStatusLink."FSN Maximum billing")
                                                end;
                                        end;
                                    end;
                                end;
                            end;
                        end;
                    end;
                end;
            end;
    end;

    //////////////////////////////Max. Descuento/Max. total////////////////////////////////////////
    procedure ValCouponTotalPress(Coupon: Code[20]; ReceiptV: Code[20]): Boolean
    var
        myInt: Integer;
        LSCPOSTransLineV: Record "LSC POS Trans. Line";
        LSCPeriodicType: Record "LSC POS Trans. Per. Disc. Type";
        PeriodicDiscont: Record "LSC Periodic Discount";
        message: Text;
    begin
        LSCPOSTransLineV.Reset();
        LSCPOSTransLineV.SetRange("Receipt No.", ReceiptV);
        LSCPOSTransLineV.SetRange("Entry Type", LSCPOSTransLineV."Entry Type"::Item);
        LSCPOSTransLineV.SetRange("Entry Status", LSCPOSTransLineV."Entry Status"::" ");
        IF LSCPOSTransLineV.Find('-') then begin
            repeat
                LSCPeriodicType.Reset();
                LSCPeriodicType.SetRange("Receipt No.", LSCPOSTransLineV."Receipt No.");
                LSCPeriodicType.SetRange("Line No.", LSCPOSTransLineV."Line No.");
                LSCPeriodicType.SetRange("Periodic Disc. Type", LSCPeriodicType."Periodic Disc. Type"::"Disc. Offer");
                if LSCPeriodicType.FindFirst() then begin
                    if PeriodicDiscont.Get(LSCPeriodicType."Offer No.") then
                        if PeriodicDiscont."Coupon Code" = Coupon then begin
                            if ValOfferMax(LSCPeriodicType."Periodic Disc. Group", LSCPeriodicType."Receipt No.", LSCPeriodicType."Line No.", LSCPeriodicType."Discount Amount", message) then begin
                                error(message);
                                exit(true);
                            end;
                        end;
                end;
            until LSCPOSTransLineV.Next() = 0;
        end;
    end;

    procedure VoidedCoupon(OfferNo: Code[20]; Receipt: Code[20])
    var
        POSTransLineVoided: Record "LSC POS Trans. Line";
        PeriodicDiscont: Record "LSC Periodic Discount";
    begin
        if PeriodicDiscont.Get(OfferNo) then begin
            POSTransLineVoided.Reset();
            POSTransLineVoided.SetRange("Receipt No.", Receipt);
            POSTransLineVoided.SetRange(POSTransLineVoided."Entry Type", POSTransLineVoided."Entry Type"::Coupon);
            POSTransLineVoided.SetRange(POSTransLineVoided."Coupon Code", PeriodicDiscont."Coupon Code");
            POSTransLineVoided.SetRange(POSTransLineVoided."Entry Status", POSTransLineVoided."Entry Status"::" ");
            IF POSTransLineVoided.FindFirst() THEN BEGIN
                POSTransLineVoided."Entry Status" := POSTransLineVoided."Entry Status"::Voided;
                POSTransLineVoided.Modify();
                POSTransLineVoided.VoidLine();
                POSTranCod.RemoveCouponDiscount(POSTransLineVoided);
            END;
        end;
    end;

    procedure ValOfferMax(OfferNo: Code[20]; ReceiptOffer: Code[20]; LineOffer: Integer; ValDiscount: Decimal; var MessageError: Text): Boolean
    var
        myInt: Integer;
        PeriodicDiscont: Record "LSC Periodic Discount";
        POSTransPeriodicDiscLine: Record "LSC POS Trans. Per. Disc. Type";
        TEXT000: Label 'Excede el maximo de descueto que es $%1, para el cupon %2, Descuento total del Cupon $%3';
        TEXT001: Label 'Excede balance maximo que es $%1, para el cupon %2, Balance del cupon $%3';
        PosTransLine: Record "LSC POS Trans. Line";
        PosTransaction: Record "LSC POS Transaction";
    begin
        MessageError := '';
        if PeriodicDiscont.Get(OfferNo) then begin
            if PeriodicDiscont."Coupon Code" <> '' then begin
                case PeriodicDiscont."FSN Type Val. Offer" of
                    PeriodicDiscont."FSN Type Val. Offer"::"Max. Descuento":
                        begin
                            POSTransPeriodicDiscLine.Reset();
                            POSTransPeriodicDiscLine.SetRange("Receipt No.", ReceiptOffer);
                            POSTransPeriodicDiscLine.SetFilter(POSTransPeriodicDiscLine."Line No.", '<>%1', LineOffer);
                            POSTransPeriodicDiscLine.SetRange("Periodic Disc. Group", PeriodicDiscont."No.");
                            POSTransPeriodicDiscLine.SetRange("Entry Status", POSTransPeriodicDiscLine."Entry Status"::" ");
                            if POSTransPeriodicDiscLine.Find('-') then begin
                                repeat
                                    ValDiscount := ValDiscount + POSTransPeriodicDiscLine."Discount Amount";
                                until POSTransPeriodicDiscLine.Next() = 0;
                            end;
                            MessageError := StrSubstNo(TEXT000, PeriodicDiscont."FSN Amount Discont/Purchase", PeriodicDiscont."Coupon Code", ValDiscount);
                        end;
                    PeriodicDiscont."FSN Type Val. Offer"::"Max. Compra":
                        begin
                            ValDiscount := 0;
                            /*POSTransPeriodicDiscLine.Reset();
                            POSTransPeriodicDiscLine.SetRange("Receipt No.", ReceiptOffer);
                            POSTransPeriodicDiscLine.SetRange("Periodic Disc. Group", PeriodicDiscont."No.");
                            POSTransPeriodicDiscLine.SetRange("Entry Status", POSTransPeriodicDiscLine."Entry Status"::" ");
                            if POSTransPeriodicDiscLine.Find('-') then begin
                                repeat
                                    PosTransLine.Reset();
                                    PosTransLine.SetRange("Receipt No.", POSTransPeriodicDiscLine."Receipt No.");
                                    PosTransLine.SetRange(PosTransLine."Line No.", POSTransPeriodicDiscLine."Line No.");
                                    IF PosTransLine.FindFirst() THEN
                                        ValDiscount := ValDiscount + PosTransLine.Amount;
                                until POSTransPeriodicDiscLine.Next() = 0;
                            end;*/
                            POSTransPeriodicDiscLine.Reset();
                            POSTransPeriodicDiscLine.SetRange("Receipt No.", ReceiptOffer);
                            POSTransPeriodicDiscLine.SetRange("Periodic Disc. Group", PeriodicDiscont."No.");
                            POSTransPeriodicDiscLine.SetRange("Entry Status", POSTransPeriodicDiscLine."Entry Status"::" ");
                            if POSTransPeriodicDiscLine.FindFirst() then begin
                                PosTransLine.Reset();
                                PosTransLine.SetRange("Receipt No.", POSTransPeriodicDiscLine."Receipt No.");
                                PosTransLine.SetRange(PosTransLine."Entry Status", PosTransLine."Entry Status"::" ");
                                IF PosTransLine.Find('-') THEN
                                    repeat
                                        ValDiscount := ValDiscount + PosTransLine.Amount;
                                    UNTIL PosTransLine.Next() = 0;
                            end;
                            MessageError := StrSubstNo(TEXT001, PeriodicDiscont."FSN Amount Discont/Purchase", PeriodicDiscont."Coupon Code", ValDiscount);
                        end;
                end;


                if ValDiscount <> 0 then begin
                    if PeriodicDiscont."FSN Amount Discont/Purchase" <> 0 then
                        if ValDiscount > PeriodicDiscont."FSN Amount Discont/Purchase" then begin
                            Message(TEXT000, PeriodicDiscont."FSN Amount Discont/Purchase", PeriodicDiscont."Coupon Code");
                            exit(true);
                        end;
                end;
            end;
        end;
    end;
    //////////////////////////////END Max. Descuento/Max. total////////////////////////////////////////

    [EventSubscriber(ObjectType::Table, Database::"LSC Periodic Discount", 'OnBeforeModifyEvent', '', true, true)]
    local procedure "LSC Periodic Discount_OnBeforeModifyEvent"
   (
       var Rec: Record "LSC Periodic Discount";
       var xRec: Record "LSC Periodic Discount";
       RunTrigger: Boolean
   )
    var
        PeriodicDiscLine: Record "LSC Periodic Discount Line";
        Parametro: Record "FSN Parameter";
    begin
        if Parametro.Get('OFFERT', 'TYPE') then
            if not Parametro.Activo then
                exit;
        if (Rec.Status = Rec.Status::Enabled) then begin
            PeriodicDiscLine.SetRange("Offer No.", Rec."No.");
            PeriodicDiscLine.SetRange("Disc. Type", PeriodicDiscLine."Disc. Type"::"Deal Price");
            if PeriodicDiscLine.FindSet() then begin
                repeat
                    PeriodicDiscLine."Disc. Type" := PeriodicDiscLine."Disc. Type"::"Disc. %";
                    PeriodicDiscLine.Modify(true);
                until PeriodicDiscLine.Next() = 0;
            end;
        end;
    end;

    [EventSubscriber(ObjectType::Table, Database::"LSC Periodic Discount Line", 'OnBeforeModifyEvent', '', true, true)]
    local procedure "LSC Periodic Discount Line_OnBeforeModifyEvent"
    (
        var Rec: Record "LSC Periodic Discount Line";
        var xRec: Record "LSC Periodic Discount Line";
        RunTrigger: Boolean
    )
    var
        PeriodicDisc: Record "LSC Periodic Discount";
        Parametro: Record "FSN Parameter";
    begin
        if Parametro.Get('OFFERT', 'TYPE') then
            if not Parametro.Activo then
                exit;
        if (Rec."Offer No." <> '') then begin
            if PeriodicDisc.Get(Rec."Offer No.") then begin
                if PeriodicDisc.Status = PeriodicDisc.Status::Enabled then begin
                    if Rec."Disc. Type" = Rec."Disc. Type"::"Deal Price" then begin
                        Rec.Validate("Disc. Type", Rec."Disc. Type"::"Disc. %");
                        Rec.CreateActions(1);
                    end;
                end;
            end;
        end;
    end;


}
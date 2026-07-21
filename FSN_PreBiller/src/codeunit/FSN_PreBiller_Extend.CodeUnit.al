/// <summary>
/// Codeunit FSN PreBiller Extend (ID 50084).
/// </summary>
codeunit 50084 "FSN PreBiller Extend"
{
    trigger OnRun()
    begin
    end;

    var
        GLOBALDESCRIPTIONV: Array[50] of Code[100];
        POSGUI: Codeunit "LSC POS GUI";
        DiscGroup: Code[20];
        TextTest: Label 'TESTING';
        OnlyCalculate: Boolean;
    #region [External procedure]

    /// <summary>
    /// calculateTheItemsDiscountWithoutGeneratingTheTransaction.
    /// </summary>
    procedure CalculateDiscount
    (
        var Arr_Item: Array[50] of Code[20];
        var Arr_Description: Array[50] of Code[100];
        var Arr_Unit_Of_Measure: Array[50] of Code[20];
        var Arr_Qty: Array[50] of Integer;
        var Arr_EntryType: Array[50] of Integer;
        CustomerNo: Code[20];
        var Arr_UnitPriceIncVAT: Array[50] of Decimal;
        var Arr_Discount: Array[50] of Decimal;
        var Arr_Amount: Array[50] of Decimal;
        var Arr_EffDisc: Array[50] of Decimal;
        var Arr_EffAmt: Array[50] of Decimal;
        var TotalDiscount: Decimal;
        var TotalAmount: Decimal;
        var Balance: Decimal;
        var BalanceVIP: Decimal;
        MemberCardNo: Code[20]
    )
    var
        _itemInfoExt: Record "FSN Item Info. Extend";
        itemInfoExt: Record "FSN Item Info. Extend";
        ISVIP: Boolean;
        _Amount: Decimal;
        _Discount: Decimal;
        i, length : Integer;
    begin
        length := ArrayLen(Arr_Item);

        Clear(TotalAmount);
        Clear(TotalDiscount);
        Clear(BalanceVIP);

        if GroupDiscountSelected(itemInfoExt, CustomerNo, MemberCardNo, ISVIP) then begin
            for i := 1 to length do begin
                if Arr_EntryType[i] = 0 then begin
                    itemInfoExt.SetRange("No.", Arr_Item[i]);
                    itemInfoExt.SetRange("Unit of Measure", Arr_Unit_Of_Measure[i]);
                    if itemInfoExt.FindFirst() then begin
                        Arr_Description[i] := itemInfoExt.Description;
                        Arr_UnitPriceIncVAT[i] := itemInfoExt."Price Default";

                        VerifyBonus(Arr_Qty[i], _Amount, _Discount, itemInfoExt, ISVIP);
                        Arr_Amount[i] := _Amount;
                        Arr_Discount[i] := _Discount;

                        TotalAmount += (Arr_Qty[i] * itemInfoExt."Price Default");
                        TotalDiscount += Arr_Amount[i];
                    end else begin
                        _itemInfoExt.Reset();
                        _itemInfoExt.SetRange("Entry Type", _itemInfoExt."Entry Type"::EcommerceItem);
                        _itemInfoExt.SetRange("Sub Type", _itemInfoExt."Sub Type"::ItemSetting);
                        _itemInfoExt.SetRange("No.", Arr_Item[i]);
                        _itemInfoExt.SetRange("Unit of Measure", Arr_Unit_Of_Measure[i]);
                        if _itemInfoExt.FindFirst() then begin
                            Arr_Description[i] := _itemInfoExt.Description;
                            Arr_UnitPriceIncVAT[i] := _itemInfoExt."Price Default";

                            VerifyBonus(Arr_Qty[i], _Amount, _Discount, _itemInfoExt, ISVIP);
                            Arr_Amount[i] := _Amount;
                            Arr_Discount[i] := _Discount;

                            TotalAmount += (Arr_Qty[i] * _itemInfoExt."Price Default");
                            TotalDiscount += Arr_Amount[i];
                        end;
                    end;

                    if not ISVIP then begin
                        _itemInfoExt.Reset();
                        _itemInfoExt.SetRange("Entry Type", _itemInfoExt."Entry Type"::EcommercePrices);
                        _itemInfoExt.SetRange("Sub Type", _itemInfoExt."Sub Type"::ItemSetting);
                        _itemInfoExt.SETRANGE("Line No.", 0);
                        _itemInfoExt.SETRANGE(ID, 'VIP');
                        _itemInfoExt.SetRange("No.", Arr_Item[i]);
                        _itemInfoExt.SetRange("Unit of Measure", Arr_Unit_Of_Measure[i]);
                        if _itemInfoExt.FindFirst() then begin
                            VerifyBonus(Arr_Qty[i], _Amount, _Discount, _itemInfoExt, ISVIP);
                            BalanceVIP += ((Arr_Qty[i] * _itemInfoExt."Price Default") - _Amount);
                        end else
                            BalanceVIP += ((Arr_Qty[i] * itemInfoExt."Price Default") - Arr_Amount[i]);
                    end;

                    Arr_EffDisc[i] := 0;
                    Arr_EffAmt[i] := 0;
                end;

                if Arr_EntryType[i] = 1 then begin
                    Clear(Arr_Item[i]);
                    Clear(Arr_Qty[i]);
                    Clear(Arr_EntryType[i]);
                end;
            end;

            TotalDiscount := -TotalDiscount;
            Balance := TotalAmount + TotalDiscount;
            if ISVIP then
                BalanceVIP := Balance;
        end;
    end;

    local procedure ParameterPref(): Boolean;
    var
        myInt: Integer;
        FSNParameter: Record "FSN Parameter";
    begin
        FSNParameter.Reset();
        FSNParameter.SetCurrentKey(Grupo, Codigo);
        FSNParameter.SetRange(Grupo, 'PREBILLER');
        FSNParameter.SetRange(Codigo, 'CHANGESQ');
        if not FSNParameter.FindFirst() then
            exit(false);
        if FSNParameter.Activo then
            exit(true);
    end;

    /// <summary>
    /// busca el ultimo numero de la secuencia de recibo de prefacturador y lo incrementa en 1
    /// </summary>
    /// <param name="Terminal">No. Terminal</param>
    /// <returns>Numero de recibo ya incrementado en 1</returns>
    procedure GetLastReceiptNumber(Terminal: Text) ReceiptNo: Code[20];
    var
        RetailSetup: Record "LSC Retail Setup";
        posfunc: Codeunit "LSC POS Functions";
        LastReceiptNo: Code[20];
        SplitReceiptNo: array[2] of Code[20];
        NoSeriesMgt: Codeunit NoSeriesManagement;

    begin
        //? recibir datos
        if ParameterPref then begin
            ReceiptNo := NoSeriesMgt.GetNextNo('PREFACTURA', Today, true);
            exit(ReceiptNo);
        end;

        RetailSetup.Get();
        LastReceiptNo := IncStr(RetailSetup."FSN WS Pref. Receipt No.");

        //? Escribir la estructura de recibo 
        SplitReceiptNo[1] := CopyStr(LastReceiptNo, 1, StrPos(LastReceiptNo, '-'));
        SplitReceiptNo[1] := DelChr(SplitReceiptNo[1], '=', '-');
        SplitReceiptNo[2] := CopyStr(LastReceiptNo, StrPos(LastReceiptNo, '-') + 1, StrLen(LastReceiptNo));
        ReceiptNo := SplitReceiptNo[1] + Terminal + posfunc.ZeroPad(SplitReceiptNo[2], 19 - StrLen(Terminal) - StrLen(SplitReceiptNo[1]));

        //? Actualizar el numero de recibo
        LastReceiptNo := InsStr(ReceiptNo, '-', StrPos(ReceiptNo, Terminal));
        LastReceiptNo := DelStr(ReceiptNo, StrPos(ReceiptNo, Terminal), StrLen(Terminal) + 1);
        RetailSetup."FSN WS Pref. Receipt No." := LastReceiptNo;
        RetailSetup.Modify();
    end;

    procedure GlobalSusped(OnlyCalc: Boolean)
    var
        myInt: Integer;
    begin
        OnlyCalculate := OnlyCalc;
    end;
    /// <summary>
    /// Obtiene el grupo de descuento del cliente por su tarjeta de membresia
    /// </summary>
    /// <param name="MemberCardNo">No. tarjeta</param>
    /// <returns>devuelve el grupo de descuento a aplicar</returns>
    procedure GetValidCustDiscGroup(MemberCardNo: Code[20]) CustDiscGroup: Code[20];
    var
        MemberAccount: Record "LSC Member Account";
        MemberClub: Record "LSC Member Club";
        MemberScheme: Record "LSC Member Scheme";
        MemberCard: Record "LSC Membership Card";
        MemberMgt: Codeunit "LSC Member Card Management";
        messagetext: Text[250];
    begin
        if not MemberMgt.GetMembershipCard(MemberCardNo, MemberCard, messagetext) then
            exit;

        if MemberAccount.Get(MemberCard."Account No.") then
            CustDiscGroup := MemberAccount."Cust. Disc. Group";

        if CustDiscGroup <> '' then
            exit;

        if MemberScheme.Get(MemberCard."Scheme Code") then
            CustDiscGroup := MemberScheme."Default Cust. Disc. Group";

        if CustDiscGroup <> '' then
            exit;

        if MemberClub.Get(MemberCard."Club Code") then
            CustDiscGroup := MemberClub."Default Cust. Disc. Group";

        exit;
    end;

    /// <summary>
    /// Obtiene el grupo de descuento del cliente por su ID
    /// </summary>
    /// <param name="CustomerNo">Codigo de Cliente</param>
    /// <param name="CurrentDiscGroup">grupo por defecto</param>
    /// <returns>Devuelve el grupo de descuento del cliente</returns>
    procedure GetDiscGroupByCustomer(CustomerNo: Code[20]; CurrentDiscGroup: Code[20]) CustDiscGroup: Code[20];
    var
        LSCMemberAcc: Record "LSC Member Account";
        LSCMemberScheme: Record "LSC Member Scheme";
        LSCMemberClub: Record "LSC Member Club";
        LSCMembershipCard: Record "LSC Membership Card";
    begin
        LSCMemberAcc.Reset();
        LSCMemberAcc.SetRange("Linked To Customer No.", CustomerNo);
        if LSCMemberAcc.FindFirst() then begin
            LSCMembershipCard.Reset();
            LSCMembershipCard.SetRange("Account No.", LSCMemberAcc."No.");
            LSCMembershipCard.SetRange(Status, LSCMembershipCard.Status::Active);
            LSCMembershipCard.SetFilter("Last Valid Date", '>=%1', Today);
            if not LSCMembershipCard.FindFirst() then begin
                CustDiscGroup := CurrentDiscGroup;
                exit;
            end;
            CustDiscGroup := LSCMemberAcc."Cust. Disc. Group";
        end;

        if CustDiscGroup <> '' then
            exit;

        if LSCMemberScheme.Get(LSCMemberAcc."Scheme Code") then
            CustDiscGroup := LSCMemberScheme."Default Cust. Disc. Group";

        if CustDiscGroup <> '' then
            exit;

        if LSCMemberClub.Get(LSCMemberAcc."Club Code") then
            CustDiscGroup := LSCMemberClub."Default Cust. Disc. Group";

        if CustDiscGroup <> '' then
            exit;

        CustDiscGroup := CurrentDiscGroup;

        exit;
    end;

    procedure GetDiscGroupCustomer(CustomerNo: Code[20]; CurrentDiscGroup: Code[20]) CustDiscGroup: Code[20];
    var
        LSCMemberAcc: Record "LSC Member Account";
        LSCMemberScheme: Record "LSC Member Scheme";
        LSCMemberClub: Record "LSC Member Club";
        LSCMembershipCard: Record "LSC Membership Card";
    begin
        LSCMemberAcc.Reset();
        LSCMemberAcc.SetRange("Linked To Customer No.", CustomerNo);
        if LSCMemberAcc.FindFirst() then begin
            LSCMembershipCard.Reset();
            LSCMembershipCard.SetRange("Account No.", LSCMemberAcc."No.");
            LSCMembershipCard.SetRange(Status, LSCMembershipCard.Status::Active);
            LSCMembershipCard.SetFilter("Last Valid Date", '>=%1', Today);
            if not LSCMembershipCard.FindFirst() then begin
                CustDiscGroup := CurrentDiscGroup;
                exit;
            end;
            CustDiscGroup := LSCMemberAcc."Cust. Disc. Group";
        end;

        if LSCMemberAcc.Get(LSCMembershipCard."Account No.") then
            CustDiscGroup := LSCMemberAcc."Cust. Disc. Group";

        if CustDiscGroup <> '' then
            exit;

        if LSCMemberScheme.Get(LSCMembershipCard."Scheme Code") then
            CustDiscGroup := LSCMemberScheme."Default Cust. Disc. Group";

        if CustDiscGroup <> '' then
            exit;

        if LSCMemberClub.Get(LSCMembershipCard."Club Code") then
            CustDiscGroup := LSCMemberClub."Default Cust. Disc. Group";

        if CustDiscGroup <> '' then
            exit;

        CustDiscGroup := CurrentDiscGroup;
        exit;
    end;

    /// <summary>
    /// 
    /// </summary>
    /// <param name="REC"></param>
    procedure ProcessCustomer(REC: Record "LSC POS transaction")
    var
        OfferPosCalc: Record "LSC Offer Pos Calculation";
        PosMixMatchEntry: Record "LSC POS Mix & Match Entry";
        POSTransLine2: Record "LSC POS Trans. Line";
        DT: Record "LSC POS Trans. Per. Disc. Type";
        POSTransPerDisc: Record "LSC POS Trans. Per. Disc. Type";
        PosFunc: Codeunit "LSC POS Functions";
        PosOfferExt: Codeunit "LSC POS Offer Ext. Utility";
        PosPriceUtil: Codeunit "LSC POS Price Utility";
        LocalizationExt: Codeunit "LSC Retail Localization Ext.";
        PromOnCustDiscGroup: Boolean;
        lPrice: Decimal;
        lQty: Decimal;
        OfferType: Option "Periodic Disc.",Customer,InfoCode,Total,Line,Promotion,Deal,"Total Discount","Tender Type","Item Point","Line Discount";
    begin
        PromOnCustDiscGroup := PosPriceUtil.IsPromotionForCustDiscGroup(REC."Customer Disc. Group", REC);
        POSTransLine2.Reset;
        POSTransLine2.SetRange("Receipt No.", REC."Receipt No.");
        POSTransLine2.SetRange("Entry Type", POSTransLine2."Entry Type"::Item);
        if POSTransLine2.FindSet then
            repeat
                Clear(OfferPosCalc);
                OfferPosCalc.SetRange("Receipt No.", POSTransLine2."Receipt No.");
                OfferPosCalc.SetRange("Trans. Line No.", POSTransLine2."Line No.");
                OfferPosCalc.DeleteAll;
                if LocalizationExt.IsNALocalizationEnabled then begin
                    PosMixMatchEntry.SetRange("Receipt No.", POSTransLine2."Receipt No.");
                    PosMixMatchEntry.SetRange("Line No.", POSTransLine2."Line No.");
                    PosMixMatchEntry.DeleteAll;
                end;
                PosPriceUtil.InsertTransDiscPercent(POSTransLine2, 0, POSTransPerDisc.DiscType::"Periodic Disc.".AsInteger(), '');
                if PromOnCustDiscGroup then begin
                    lPrice := POSTransLine2.Price;
                    lQty := POSTransLine2.Quantity;
                    PosPriceUtil.InsertTransDiscPercent(POSTransLine2, 0, DT.DiscType::"Periodic Disc.".AsInteger(), '');
                    POSTransLine2."Promotion No." := '';
                    POSTransLine2."Mix & Match Line No." := 0;
                    PosPriceUtil.InsertTransDiscAmount(POSTransLine2, 0, DT.DiscType::"Periodic Disc.".AsInteger(), '');
                    if not POSTransLine2."Price Change" then
                        PosPriceUtil.CalcPrice(POSTransLine2, false);
                    if (lPrice <> POSTransLine2.Price) then begin
                        POSTransLine2.Validate(Quantity, lQty);
                        POSTransLine2.Modify(true);
                    end;
                end;
                PosFunc.ClearPosTransLineOffers(POSTransLine2);
                PosPriceUtil.InitGlobals(POSTransLine2, true);
                PosPriceUtil.FindPeriodicOffers(POSTransLine2);
                PosFunc.AddPosTransLineOffers(POSTransLine2);
                POSTransLine2.Modify(true);
            until POSTransLine2.Next = 0;
        PosPriceUtil.CalcPeriodicOnTotalPressed(REC);
        PosFunc.RecalcSlip(REC);
        PosOfferExt.ReCalcOfferSeq(REC, OfferType::"Total Discount");
    end;

    /// <summary>
    /// valida si el proceso es valido para saltarse la generacion de transacciones
    /// </summary>
    Procedure ValidateCalculateProcess
    (
        Bin: Code[10];
        OnlyCalculate: Boolean;
        MemberCardNo: Code[20];
        Arr_Item: Array[50] of Code[20];
        Arr_EntryType: Array[50] of Integer;
        ManagerKey: Code[20]
    ): boolean;
    var
        FSNParameter: Record "FSN Parameter";
        SpecialGroup: Record "LSC Item Special Groups";
        OK: Boolean;
        i: Integer;
    begin
        //Testing
        /* 
        if ManagerKey <> '99999999' then
            exit(false); 
        */
        if not OnlyCalculate then
            exit(false);

        Clear(OK);
        for i := 1 to ArrayLen(Arr_Item) do begin
            if not OK then
                ok := (Arr_EntryType[i] = 1) and (Arr_Item[i] = '20') and (Bin = '');
        end;
        if not OK then
            exit(false);

        if MemberCardNo <> '' then begin
            DiscGroup := GetValidCustDiscGroup(MemberCardNo);
            if not (DiscGroup in ['RETAIL', 'VIP', 'FASANI']) then begin
                Clear(DiscGroup);
                exit(false);
            end;
        end;

        FSNParameter.Reset();
        FSNParameter.SetCurrentKey(Grupo, Codigo);
        FSNParameter.SetRange(Grupo, 'PREBILLER');
        FSNParameter.SetRange(Codigo, 'ONLYCALC');
        if not FSNParameter.FindFirst() then
            exit(false)
        else
            if not FSNParameter.Activo then
                exit(false);

        exit(true);
    end;

    /// <summary>
    /// getIndex.
    /// </summary>
    /// <param name="Arr">Array[50] of Integer.</param>
    /// <param name="Value">integer.</param>
    /// <returns>Return value of type Integer.</returns>
    procedure getIndex(Arr: Array[50] of Integer; Value: integer): Integer;
    var
        i: Integer;

    begin
        for i := 1 to ArrayLen(Arr) do begin
            if Arr[i] = Value then
                exit(i);
        end;
        exit(0);
    end;

    /// <summary>
    /// getIndex.
    /// </summary>
    /// <param name="Arr">Array[50] of Code[20].</param>
    /// <param name="Value">Code[20].</param>
    /// <returns>Return value of type Integer.</returns>
    procedure getIndex(Arr: Array[50] of Code[20]; Value: Code[20]): Integer;
    var
        i: Integer;

    begin
        for i := 1 to ArrayLen(Arr) do begin
            if Arr[i] = Value then
                exit(i);
        end;
        exit(0);
    end;
    #endregion

    #region [Internal procedure]
    local procedure GroupDiscountSelected
    (
        var ItemInfoExt: Record "FSN Item Info. Extend";
        CustomerNo: Code[20];
        MemberCardNo: Code[20];
        var ISVIP: Boolean
    ): Boolean;
    var
        Customer: Record Customer;
        EntryType: Option;
    begin
        Clear(ISVIP);

        if not Customer.Get(CustomerNo) then
            exit(false);

        if DiscGroup <> '' then begin
            if not MemberCardValidityStatus(MemberCardNo) then
                DiscGroup := Customer."Customer Disc. Group";
        end else
            DiscGroup := Customer."Customer Disc. Group";

        ItemInfoExt.Reset();

        case DiscGroup of
            'RETAIL':
                EntryType := ItemInfoExt."Entry Type"::EcommerceItem;
            'VIP':
                begin
                    EntryType := ItemInfoExt."Entry Type"::EcommercePrices;
                    ItemInfoExt.SetRange("line No.", 0);
                    ItemInfoExt.SetRange(ID, 'VIP');
                    ISVIP := true;
                end;
            'FASANI':
                begin
                    EntryType := ItemInfoExt."Entry Type"::EcommercePrices;
                    ItemInfoExt.SetRange("line No.", 0);
                    ItemInfoExt.SetRange(ID, 'VIP');
                end;
        end;

        ItemInfoExt.SetRange("Entry Type", EntryType);
        ItemInfoExt.SetRange("Sub Type", ItemInfoExt."Sub Type"::ItemSetting);

        exit(true);
    end;

    local procedure MemberCardValidityStatus(MemberCardNo: Code[20]): Boolean
    var
        MemberCard: Record "LSC Membership Card";
    begin
        if not MemberCard.Get(MemberCardNo) then
            exit(false);

        if MemberCard.Status <> MemberCard.Status::Active then
            exit(false);

        if MemberCard."Last Valid Date" < Today then
            exit(false);

        exit(true);
    end;

    local procedure VerifyBonus
    (
        Qty: Integer;
        var Amount: Decimal;
        var Discount: Decimal;
        ItemInfoExt: Record "FSN Item Info. Extend";
        ISVIP: Boolean
    ): Boolean;
    var
        PeriodicDiscountLine: Record "LSC Periodic Discount Line";
        FindItem: Boolean;
        promos: Integer;
    begin
        Clear(FindItem);
        Clear(Amount);
        Clear(Discount);

        PeriodicDiscountLine.Reset();
        PeriodicDiscountLine.SetRange("No.", ItemInfoExt."No.");
        PeriodicDiscountLine.SetRange("Offer No.", 'MMSUIZOS_2+1_VIP');
        if PeriodicDiscountLine.FindFirst() then
            FindItem := true;

        if (Qty >= 3) and FindItem and ISVIP then begin
            promos := Qty div 3;
            Discount := (promos / Qty) * 100;
        end else
            if (DiscGroup = 'FASANI') and FindItem then
                Discount := ItemInfoExt."Discount Default" + 5.00
            else
                Discount := ItemInfoExt."Discount Default";

        Amount := Round((Qty * ItemInfoExt."Price Default") * (Discount / 100), 0.01);
    end;
    #endregion
    /// <summary>
    /// CalculationProcess.
    /// </summary>
    /// <param name="arrItem">VAR Array[50] of Code[20].</param>
    /// <param name="arrDescription">VAR Array[50] of Code[100].</param>
    /// <param name="arrUnitOfMeasure">VAR Array[50] of Code[20].</param>
    /// <param name="arrQty">VAR Array[50] of Integer.</param>
    /// <param name="arrEntryType">VAR Array[50] of Integer.</param>
    /// <param name="arrUnitPriceIncVAT">VAR Array[50] of Decimal.</param>
    /// <param name="arrDiscount">VAR Array[50] of Decimal.</param>
    /// <param name="arrAmount">VAR Array[50] of Decimal.</param>
    /// <param name="arrEffDisc">VAR Array[50] of Decimal.</param>
    /// <param name="arrEffAmt">VAR Array[50] of Decimal.</param>
    /// <param name="totalDiscount">VAR Decimal.</param>
    /// <param name="totalAmount">VAR Decimal.</param>
    /// <param name="balance">VAR Decimal.</param>
    /// <param name="balanceVIP">VAR Decimal.</param>
    /// <param name="customerNo">Code[20].</param>
    /// <param name="memberCardNo">Code[20].</param>
    procedure CalculationProcess(
        var arrItem: Array[50] of Code[20];
        var arrDescription: Array[50] of Code[100];
        var arrUnitOfMeasure: Array[50] of Code[20];
        var arrQty: Array[50] of Integer;
        var arrEntryType: Array[50] of Integer;
        var arrUnitPriceIncVAT: Array[50] of Decimal;
        var arrDiscount: Array[50] of Decimal;
        var arrAmount: Array[50] of Decimal;
        var arrEffDisc: Array[50] of Decimal;
        var arrEffAmt: Array[50] of Decimal;
        var totalDiscount: Decimal;
        var totalAmount: Decimal;
        var balance: Decimal;
        var balanceVIP: Decimal;
        customerNo: Code[20];
        memberCardNo: Code[20];
        var Response_Text: Text
    )
    var
        useByMixMatch: array[50] of Boolean;
        perDiscount, _perDisct : Record "LSC Periodic Discount";
        discounts: Query "Periodic Discount";
        customer: Record Customer;
        _perDisctTemp, _perDisctVIPtemp : Record "LSC Periodic Discount" temporary;
        perDiscountLine, LineVIP : Record "LSC Periodic Discount Line";
        discGroup: Code[20];
        itemsToOffer: List of [Integer];
        i, offertCount, priority, INT_MAX : Integer;
        item: Record Item;
        iuom: Record "Item Unit of Measure";
        salesPrice: Record "Sales Price";
        Offerts: Dictionary of [code[20], List of [Code[20]]];
        RetailPriceUtil: Codeunit "LSC Retail Price Utils";
        DiscValPer: Record "LSC Validation Period";
        Currency: Record Currency;
        POSinfocodeSubCode: Record "LSC information Subcode";
        TableSpecInfocode: Record "LSC Table Specific Infocode";
    begin

        //? Eliminar entry type 2
        DeleteEntryType(arrItem, arrDescription, arrUnitOfMeasure, arrQty, arrEntryType, arrUnitPriceIncVAT, arrDiscount, arrAmount, arrEffDisc, arrEffAmt);
        MergeDuplicateLines(arrItem, arrDescription, arrUnitOfMeasure, arrQty, arrEntryType, arrUnitPriceIncVAT, arrDiscount, arrAmount, arrEffDisc, arrEffAmt);
        //? Entero maximo posible del lenguaje AL
        INT_MAX := 2147483647;
        if Currency.get('US') then;
        //? Validacion del grupo de descuento del cliente
        if customer.Get(customerNo) then;
        if memberCardNo <> '' then
            discGroup := GetValidCustDiscGroup(memberCardNo)
        else
            discGroup := GetDiscGroupCustomer(customerNo, customer."Customer Disc. Group");

        if customerNo = '' then
            discGroup := 'WITHOUT_DISCOUNT';

        for i := 1 to ArrayLen(arrItem) do begin
            if arrItem[i] <> '' then
                if arrEntryType[i] = 0 then begin
                    if not ValidateItemVariants(arrItem[i]) then begin
                        priority := INT_MAX;

                        Clear(_perDisctTemp);
                        Clear(discounts);
                        discounts.SetRange("No", arrItem[i]);
                        discounts.Open();
                        while discounts.Read() do begin
                            if (EvaluatePeriodicDisc(
                                        discounts,
                                        arrItem,
                                        arrUnitOfMeasure,
                                        arrQty,
                                        useByMixMatch,
                                        arrItem[i],
                                        arrQty[i],
                                        arrUnitOfMeasure[i],
                                        discGroup,
                                        i
                                    ))
                            and (discounts.Priority < priority) then begin
                                if perDiscount.Get(discounts."OfferNo") then;
                                if RetailPriceUtil.DiscValPerValid(perDiscount."Validation Period ID", Today, Time) then begin
                                    priority := discounts.Priority;
                                    _perDisctTemp := perDiscount;
                                end;
                            end else
                                if perDiscount.Get(discounts."OfferNo") and (perDiscount."Customer Disc. Group" = 'VIP') and (perDiscount.Type <> perDiscount.Type::"Mix&Match") then
                                    _perDisctVIPtemp := perDiscount;
                        end;
                        discounts.Close();

                        if item.Get(arrItem[i]) then;
                        if iuom.Get(arrItem[i], arrUnitOfMeasure[i]) then;
                        salesPrice.Reset();
                        salesPrice.SetRange("Item No.", arrItem[i]);
                        if arrUnitOfMeasure[i] <> '' then
                            salesPrice.SetRange("Unit of Measure Code", arrUnitOfMeasure[i])
                        else
                            salesPrice.SetRange("Unit of Measure Code", item."Base Unit of Measure");

                        if salesPrice.FindSet() then;

                        perDiscountLine.Reset();
                        perDiscountLine.SetRange("No.", arrItem[i]);
                        perDiscountLine.SetRange("Offer No.", _perDisctTemp."No.");
                        if perDiscountLine.FindFirst() then begin
                            if _perDisctTemp.Type = _perDisctTemp.Type::"Mix&Match" then begin
                                itemsToOffer := createProductGroup(arrItem, arrQty, arrEntryType, arrUnitOfMeasure, useByMixMatch, arrDescription, offertCount, Response_Text, _perDisctTemp."No.", i);
                                useByMixMatch[i] := true;
                                case _perDisctTemp."Discount Type" of
                                    _perDisctTemp."Discount Type"::"Deal Price":
                                        begin
                                            calculateFinalPrice(_perDisctTemp, arrItem, arrQty, arrUnitOfMeasure, itemsToOffer, arrItem[i], arrQty[i], arrUnitPriceIncVAT[i], arrDiscount[i], arrAmount[i], arrDescription[i], offertCount);
                                        end;
                                    _perDisctTemp."Discount Type"::"Discount %":
                                        begin
                                            arrUnitPriceIncVAT[i] := salesPrice."LSC Unit Price Including VAT";
                                            arrDiscount[i] := _perDisctTemp."Discount % Value";
                                            arrAmount[i] := Round(arrUnitPriceIncVAT[i] * (arrDiscount[i] / 100) * arrQty[i], Currency."Amount Rounding Precision");
                                            arrDescription[i] := perDiscountLine.Description;
                                        end;
                                    _perDisctTemp."Discount Type"::"Line spec.":
                                        begin
                                            if perDiscountLine."Disc. Type" = perDiscountLine."Disc. Type"::"Disc. %" then begin
                                                arrUnitPriceIncVAT[i] := perDiscountLine."Standard Price Including VAT";
                                                arrDiscount[i] := perDiscountLine."Deal Price/Disc. %";
                                                arrAmount[i] := Round(arrUnitPriceIncVAT[i] * (arrDiscount[i] / 100) * arrQty[i], Currency."Amount Rounding Precision");
                                                arrDescription[i] := perDiscountLine.Description;
                                            end else begin
                                                arrUnitPriceIncVAT[i] := perDiscountLine."Standard Price Including VAT";
                                                arrDiscount[i] := 0.0;
                                                arrAmount[i] := Round(arrUnitPriceIncVAT[i] * (arrDiscount[i] / 100) * arrQty[i], Currency."Amount Rounding Precision");
                                                arrDescription[i] := perDiscountLine.Description;
                                            end;
                                        end;
                                    _perDisctTemp."Discount Type"::"Least Expensive":
                                        begin
                                            EvaluateMinorInMatch(_perDisctTemp, arrItem, arrQty, arrUnitOfMeasure, itemsToOffer, arrItem[i], arrQty[i], arrUnitPriceIncVAT[i], arrDiscount[i], arrAmount[i], arrDescription[i]);
                                        end;
                                end;
                            end else begin
                                if not useByMixMatch[i] then begin
                                    arrUnitPriceIncVAT[i] := salesPrice."LSC Unit Price Including VAT";
                                    arrDiscount[i] := perDiscountLine."Deal Price/Disc. %";
                                    arrAmount[i] := Round(arrUnitPriceIncVAT[i] * (arrDiscount[i] / 100) * arrQty[i], Currency."Amount Rounding Precision");
                                    arrDescription[i] := perDiscountLine.Description;
                                end;
                            end;
                        end else begin
                            arrUnitPriceIncVAT[i] := item."LSC Unit Price Incl. VAT" * iuom."Qty. per Unit of Measure";
                            arrDiscount[i] := 0.0;
                            arrAmount[i] := arrUnitPriceIncVAT[i] * (arrDiscount[i] / 100) * arrQty[i];
                            arrDescription[i] := item.Description;
                        end;

                        totalAmount += Round(arrUnitPriceIncVAT[i] * arrQty[i], 0.01, '=');
                        totalDiscount -= arrAmount[i];
                        balance += (arrUnitPriceIncVAT[i] * arrQty[i]) - arrAmount[i];
                        if (discGroup = 'VIP') then
                            balanceVIP := balance
                        else begin
                            if _perDisctTemp.Type = _perDisctTemp.Type::"Mix&Match" then begin
                                balanceVIP += Round((arrUnitPriceIncVAT[i] * arrQty[i]) - arrAmount[i], 0.01, '<');
                            end else begin
                                LineVIP.Reset();
                                LineVIP.SetRange("No.", arrItem[i]);
                                LineVIP.SetRange("Offer No.", _perDisctVIPtemp."No.");
                                if LineVIP.FindFirst() then begin
                                    balanceVIP += Round((arrUnitPriceIncVAT[i] - (arrUnitPriceIncVAT[i] * (LineVIP."Deal Price/Disc. %" / 100))) * arrQty[i], 0.01, '=');
                                end else
                                    balanceVIP += Round((arrUnitPriceIncVAT[i] * arrQty[i]) - arrAmount[i], 0.01, '<');
                            end;
                        end;
                    end else begin
                        POSinfocodeSubCode.RESET();
                        POSinfocodeSubCode.SETRANGE("Code", arrItem[i]);
                        POSinfocodeSubCode.SetRange(Description, arrDescription[i]);
                        IF POSinfocodeSubCode.FINDFIRST THEN BEGIN
                            arrDescription[i] := POSinfocodeSubCode.Description;
                            arrUnitPriceIncVAT[i] := POSinfocodeSubCode."Amount /Percent";
                            arrDiscount[i] := 0.0;
                            arrAmount[i] := arrUnitPriceIncVAT[i] * (arrDiscount[i] / 100) * arrQty[i];

                            totalAmount += Round(arrUnitPriceIncVAT[i] * arrQty[i], 0.01, '=');
                            totalDiscount -= arrAmount[i];
                            balance += (arrUnitPriceIncVAT[i] * arrQty[i]) - arrAmount[i];
                            balanceVIP += Round((arrUnitPriceIncVAT[i] * arrQty[i]) - arrAmount[i], 0.01, '<');
                        end;
                    end;
                end;
        end;
        //? Eliminar lineas duplicadas despues de calcular los montos
        if not ValidateItemVariants(arrItem[i]) then
            MergeDuplicateLines(arrItem, arrDescription, arrUnitOfMeasure, arrQty, arrEntryType, arrUnitPriceIncVAT, arrDiscount, arrAmount, arrEffDisc, arrEffAmt);
    end;

    procedure ValidateItemVariants(ItemCode: Code[20]): Boolean
    var
        TableSpecInfocode: Record "LSC Table Specific Infocode";
        LSCInfocode: Record "LSC Infocode";
    begin

        TableSpecInfocode.SetCurrentKey("Table ID", Value, "Infocode Code");
        TableSpecInfocode.SetRange(TableSpecInfocode."Table ID", Database::Item);
        TableSpecInfocode.SETRANGE(Value, ItemCode);
        TableSpecInfocode.SETRANGE("Infocode Code", ItemCode);
        if TableSpecInfocode.FindFirst() then begin
            if LSCInfocode.get(TableSpecInfocode."Infocode Code") then begin
                if LSCInfocode.Prompt = 'VARIANTES' then
                    exit(true)
                else
                    exit(false);

            end else
                exit(false);
        end else
            exit(false);
    end;

    procedure MergeDuplicateLines(
    var arrItem: Array[50] of Code[20];
        var arrDescription: Array[50] of Code[100];
        var arrUnitOfMeasure: Array[50] of Code[20];
        var arrQty: Array[50] of Integer;
        var arrEntryType: Array[50] of Integer;
        var arrUnitPriceIncVAT: Array[50] of Decimal;
        var arrDiscount: Array[50] of Decimal;
        var arrAmount: Array[50] of Decimal;
        var arrEffDisc: Array[50] of Decimal;
        var arrEffAmt: Array[50] of Decimal)
    var
        i, j : Integer;
        Desc: Decimal;
    begin
        for i := 1 to ArrayLen(arrItem) do begin
            if arrItem[i] <> '' then
                for j := i + 1 to ArrayLen(arrItem) do begin
                    if (arrItem[j] <> '') and
                       (arrItem[i] = arrItem[j]) and
                       (arrUnitOfMeasure[i] = arrUnitOfMeasure[j]) then begin
                        if not ValidateItemVariants(arrItem[i]) then begin
                            // Sumar cantidades y montos
                            arrQty[i] += arrQty[j];
                            arrAmount[i] += arrAmount[j];
                            if arrAmount[i] <> 0 then
                                Desc := arrAmount[i] / (arrUnitPriceIncVAT[i] * arrQty[i]);
                            arrDiscount[i] := Round(Desc * 100, 0.1);

                            arrEffDisc[i] += arrEffDisc[i];
                            arrEffAmt[i] += arrEffAmt[j];

                            // Limpiar la línea duplicada
                            arrItem[j] := '';
                            arrDescription[j] := '';
                            arrUnitOfMeasure[j] := '';
                            arrQty[j] := 0;
                            arrEntryType[j] := 0;
                            arrUnitPriceIncVAT[j] := 0;
                            arrDiscount[j] := 0;
                            arrAmount[j] := 0;
                            arrEffDisc[j] := 0;
                            arrEffAmt[j] := 0;
                        end;
                    end;
                end;
        end;
    end;

    /// <summary>
    local procedure DeleteEntryType(var arrItem: Array[50] of Code[20];
        var arrDescription: Array[50] of Code[100];
        var arrUnitOfMeasure: Array[50] of Code[20];
        var arrQty: Array[50] of Integer;
        var arrEntryType: Array[50] of Integer;
        var arrUnitPriceIncVAT: Array[50] of Decimal;
        var arrDiscount: Array[50] of Decimal;
        var arrAmount: Array[50] of Decimal;
        var arrEffDisc: Array[50] of Decimal;
        var arrEffAmt: Array[50] of Decimal)
    var
        i, j : Integer;
    begin
        for i := 1 to ArrayLen(arrEntryType) do begin
            if (arrEntryType[i] = 2) then begin
                // Limpiar la línea duplicada
                arrItem[i] := '';
                arrDescription[i] := '';
                arrUnitOfMeasure[i] := '';
                arrQty[i] := 0;
                arrEntryType[i] := 0;
                arrUnitPriceIncVAT[i] := 0;
                arrDiscount[i] := 0;
                arrAmount[i] := 0;
                arrEffDisc[i] := 0;
                arrEffAmt[i] := 0;
            end;
        end;

        //? Eliminar lineas duplicadas
        for i := 1 to ArrayLen(arrEntryType) do begin
            if arrEntryType[i] = 1 then
                for j := i + 1 to ArrayLen(arrEntryType) do begin
                    if (arrEntryType[j] = 1) then begin
                        // Limpiar la línea duplicada
                        arrItem[j] := '';
                        arrDescription[j] := '';
                        arrUnitOfMeasure[j] := '';
                        arrQty[j] := 0;
                        arrEntryType[j] := 0;
                        arrUnitPriceIncVAT[j] := 0;
                        arrDiscount[j] := 0;
                        arrAmount[j] := 0;
                        arrEffDisc[j] := 0;
                        arrEffAmt[j] := 0;
                    end;
                end;
        end;
    end;

    local procedure EvaluatePeriodicDisc(
        discount: Query "Periodic Discount";
        arrItems: Array[50] of Code[20];
        arrUnitOfMeasure: Array[50] of Code[20];
        arrQty: Array[50] of Integer;
        arrUseByMixMatch: Array[50] of Boolean;
        itemNo: Code[20];
        qty: Integer;
        unitOfMeasure: Code[20];
        discGroup: Code[20];
        i: Integer
    ): Boolean
    var
        perDisct: Record "LSC Periodic Discount";
        perDisctLine: Record "LSC Periodic Discount Line";
        meetConditions: Boolean;
        mixMatchLines: Record "LSC Periodic Discount Line";
        linesGroup: Record "LSC Mix & Match Line Groups";
        indexList: List of [Integer];
        lineDictionary: Dictionary of [Code[1], Integer];
        index, countMatchLine : Integer;
    begin
        meetConditions := true;
        if perDisct.Get(discount."OfferNo") then;
        if perDisctLine.Get(discount."OfferNo", discount."LineNo") then;

        //? validacion base para cualquier tipo de descuento
        if (perDisct."Customer Disc. Group" <> '') and (perDisct."Customer Disc. Group" <> discGroup) then
            meetConditions := false;

        if (perDisct."Coupon Code" <> '') then
            meetConditions := false;

        if perDisct."Member Value" <> '' then
            meetConditions := false;

        if perDisct."Member Attribute" <> '' then
            meetConditions := false;

        if perDisct."Member Attribute Value" <> '' then
            meetConditions := false;

        if perDisct."Amount to Trigger" <> 0 then
            meetConditions := false;

        if perDisct."Sales Type Filter" <> '' then
            meetConditions := false;

        //? validacion especifica para descuentos de mix & Match
        if (perDisct.Type = perDisct.Type::"Mix&Match") and (not arrUseByMixMatch[i]) then begin
            mixMatchLines.SetRange("Offer No.", perDisct."No.");
            if mixMatchLines.FindSet() then
                repeat
                    index := getIndex(arrItems, mixMatchLines."No.");
                    if (index <> 0) then begin
                        if lineDictionary.ContainsKey(mixMatchLines."Line Group") then begin
                            // Contar líneas, no cantidades
                            if (mixMatchLines."Unit of Measure" = arrUnitOfMeasure[index]) or (mixMatchLines."Unit of Measure" = '') then
                                lineDictionary.Set(mixMatchLines."Line Group", lineDictionary.Get(mixMatchLines."Line Group") + 1);
                        end else begin
                            if (mixMatchLines."Unit of Measure" in [arrUnitOfMeasure[index], '']) then
                                lineDictionary.Add(mixMatchLines."Line Group", 1);
                        end;
                    end;
                until (mixMatchLines.Next() = 0) or not meetConditions;

            // Validar que haya suficientes líneas por grupo
            linesGroup.SetRange("Group No.", perDisct."No.");
            if linesGroup.FindSet() then
                repeat
                    if lineDictionary.ContainsKey(linesGroup."Line Group Code") then begin
                        countMatchLine := lineDictionary.Get(linesGroup."Line Group Code");
                        if countMatchLine < linesGroup."Value 1" then
                            meetConditions := false;
                    end else
                        meetConditions := false;
                until (linesGroup.Next() = 0) or not meetConditions;
        end;

        if (perDisct.Type = perDisct.Type::"Mix&Match") and (arrUseByMixMatch[i]) then
            meetConditions := false;

        //? validacion del pruducto especifico
        if ((perDisctLine."No. of Items Needed" <> 0) and (perDisctLine."No. of Items Needed" > qty)) or
        ((perDisctLine."Unit of Measure" <> '') and (perDisctLine."Unit of Measure" <> unitOfMeasure)) then
            meetConditions := false;

        exit(meetConditions);
    end;

    local procedure calculateFinalPrice(
        offer: Record "LSC Periodic Discount";
        items: array[50] of Code[20];
        quantites: array[50] of Integer;
        unitsOfMeasure: array[50] of Code[20];
        itemsToOffer: List of [Integer];
        item: Code[20];
        qty: Integer;
        var unitPrice: Decimal;
        var discount: Decimal;
        var amount: Decimal;
        var description: Code[100];
        offerCount: Integer
    )
    var
        periodicDiscountLine: Record "LSC Periodic Discount Line";
        lineGroup: Record "LSC Mix & Match Line Groups";
        i: Integer;
        realAmount, dealPrice, difference : decimal;
    begin
        foreach i in itemsToOffer do begin
            periodicDiscountLine.Reset();
            periodicDiscountLine.SetRange("Offer No.", offer."No.");
            periodicDiscountLine.SetRange("No.", items[i]);
            if periodicDiscountLine.FindSet() then
                realAmount += periodicDiscountLine."Standard Price Including VAT" * quantites[i];

            if items[i] = item then begin
                description := periodicDiscountLine.Description;
                unitPrice := periodicDiscountLine."Standard Price Including VAT";
            end;
        end;

        difference := realAmount - (offer."Deal Price Value" * offerCount);
        discount := Round((difference / realAmount) * 100, 0.01);
        amount := (unitPrice * (discount / 100)) * qty;
    end;

    local procedure EvaluateMinorInMatch(
        offer: Record "LSC Periodic Discount";

        var items: array[50] of Code[20];
        var quantites: array[50] of Integer;
        var unitsOfMeasure: array[50] of Code[20];
        var itemsToOffer: List of [Integer];
        item: Code[20];
        qty: Integer;
        var unitPrice: Decimal;
        var discount: Decimal;
        var amount: Decimal;
        var description: Code[100]
    )
    var
        periodicDiscountLine: Record "LSC Periodic Discount Line";
        salesPrice: Record "Sales Price";
        _item: Record Item;
        i, j, minor : Integer;
        decimalMinor: Decimal;
        groups: Integer;
        totalSinOferta: Decimal;
        totalAPagar: Decimal;

    begin
        decimalMinor := 999999999999999.99;

        foreach i in itemsToOffer do begin
            periodicDiscountLine.Reset();
            periodicDiscountLine.SetRange("Offer No.", offer."No.");
            periodicDiscountLine.SetRange("No.", items[i]);
            if periodicDiscountLine.FindSet() then
                if periodicDiscountLine."Standard Price Including VAT" < decimalMinor then begin
                    decimalMinor := periodicDiscountLine."Standard Price Including VAT";
                    minor := i;
                end;
            if items[i] = item then begin
                _item.Get(item);
                salesPrice.Reset();
                salesPrice.SetRange("Item No.", item);
                if unitsOfMeasure[i] <> '' then
                    salesPrice.SetRange("Unit of Measure Code", unitsOfMeasure[i])
                else
                    salesPrice.SetRange("Unit of Measure Code", _item."Base Unit of Measure");
                salesPrice.FindSet();
                description := periodicDiscountLine.Description;
                unitPrice := Round(salesPrice."LSC Unit Price Including VAT", 0.01);
            end;
        end;

        groups := qty div periodicDiscountLine."No. of Items Needed";
        totalSinOferta := unitPrice * qty;
        totalAPagar := (qty - groups) * unitPrice;
        amount := totalSinOferta - totalAPagar;
        discount := Round((amount / totalSinOferta) * 100, 0.01);
    end;

    local procedure createProductGroup(
           var items: Array[150] of Code[20];
           var quantites: Array[150] of integer;
           var entriesType: Array[150] of Integer;
           var unitsOfMeasure: Array[150] of Code[20];
           var usedByMixMatch: Array[150] of Boolean;
           var descriptions: array[150] of Code[100];
        var offerCount: Integer;
           var Response_Text: Text;
           offer: Code[20];
           N: Integer
    ): List of [Integer];
    var
        itemsToOffer: List of [Integer];
        itemFilter: Text;
        GroupCode: Code[1];
        minimumInText: Text;
        itemUsed, minimumList : list of [Integer];
        minimunToOffer: Dictionary of [Code[1], Integer];
        actualLines: Dictionary of [Code[1], Integer];
        periodicDiscount: Record "LSC Periodic Discount";
        periodicDiscountLine: Record "LSC Periodic Discount Line";
        lineGroup: Record "LSC Mix & Match Line Groups";
        i, INT_MAX, qtyTmp, minInt : Integer;
    begin
        //? colocar la informacion de la oferta
        if periodicDiscount.Get(offer) then;
        if (getIndex(items, offer) = 0) then begin
            entriesType[getIndex(items, '')] := 2;
            unitsOfMeasure[getIndex(items, '')] := '';
            usedByMixMatch[getIndex(items, '')] := false;
            descriptions[getIndex(items, '')] := periodicDiscount."Pop-up Line 1";
            items[getIndex(items, '')] := offer;
        end;

        Clear(itemsToOffer);
        INT_MAX := 2147483647;
        i := 1;
        while (items[i] <> '') do begin
            itemFilter += items[i] + '|';
            i += 1;
        end;
        itemFilter := DelStr(itemFilter, StrLen(itemFilter), 1);

        lineGroup.SetRange("Group No.", offer);
        if lineGroup.FindSet() then
            repeat
                minimunToOffer.Add(lineGroup."Line Group Code", lineGroup."Value 1");
            until lineGroup.Next() = 0;


        periodicDiscountLine.Reset();
        periodicDiscountLine.SetRange("Offer No.", offer);
        periodicDiscountLine.SetFilter("No.", itemFilter);
        if periodicDiscountLine.FindSet() then
            repeat
                if
                (periodicDiscountLine."No. of Items Needed" <= quantites[getIndex(items, periodicDiscountLine."No.")]) then
                    if actualLines.ContainsKey(periodicDiscountLine."Line Group") then begin
                        offerCount := actualLines.Get(periodicDiscountLine."Line Group");
                        offerCount += quantites[getIndex(items, periodicDiscountLine."No.")];
                        actualLines.Set(periodicDiscountLine."Line Group", offerCount);
                        itemUsed.Add(getIndex(items, periodicDiscountLine."No."));
                    end else begin
                        actualLines.Add(periodicDiscountLine."Line Group", quantites[getIndex(items, periodicDiscountLine."No.")]);
                        itemUsed.Add(getIndex(items, periodicDiscountLine."No."));
                    end;
            until periodicDiscountLine.Next() = 0;

        foreach GroupCode in actualLines.Keys do begin
            minimumInText := Format(actualLines.Get(GroupCode) / MinimunToOffer.Get(GroupCode)).Split('.').Get(1);
            Evaluate(minInt, minimumInText);
            minimumList.Add(minInt);
        end;

        offerCount := INT_MAX;
        foreach i in minimumList do begin
            if i < offerCount then
                offerCount := i;
        end;

        quantites[getIndex(items, offer)] := offerCount div periodicDiscountLine."No. of Items Needed";

        foreach GroupCode in actualLines.Keys do begin
            actualLines.Set(GroupCode, minimunToOffer.Get(GroupCode) * offerCount);
        end;

        foreach i in itemUsed do begin
            periodicDiscountLine.Reset();
            periodicDiscountLine.SetRange("Offer No.", offer);
            periodicDiscountLine.SetRange("No.", items[i]);
            periodicDiscountLine.FindSet();

            if actualLines.Get(periodicDiscountLine."Line Group") >= quantites[getIndex(items, periodicDiscountLine."No.")] then begin
                actualLines.Set(periodicDiscountLine."Line Group", actualLines.Get(periodicDiscountLine."Line Group") - quantites[getIndex(items, periodicDiscountLine."No.")]);
                itemsToOffer.Add(i);
            end else
                if actualLines.Get(periodicDiscountLine."Line Group") > 0 then begin
                    qtyTmp := quantites[getIndex(items, periodicDiscountLine."No.")] - actualLines.Get(periodicDiscountLine."Line Group");
                    actualLines.Set(periodicDiscountLine."Line Group", 0);
                    quantites[getIndex(items, periodicDiscountLine."No.")] -= qtyTmp;
                    quantites[getIndex(items, '')] := qtyTmp;
                    entriesType[getIndex(items, '')] := entriesType[getIndex(items, periodicDiscountLine."No.")];
                    descriptions[getIndex(items, '')] := descriptions[getIndex(items, periodicDiscountLine."No.")];
                    unitsOfMeasure[getIndex(items, '')] := periodicDiscountLine."Unit of Measure";
                    usedByMixMatch[getIndex(items, '')] := true;
                    items[getIndex(items, '')] := periodicDiscountLine."No.";
                    itemsToOffer.Add(i);
                end else
                    usedByMixMatch[getIndex(items, periodicDiscountLine."No.")] := true;
        end;

        //? se eliminan los productos que no cumplen con la oferta
        ValidateQuantityOffer(items, quantites, entriesType, unitsOfMeasure, usedByMixMatch, descriptions, offerCount, Response_Text, periodicDiscountLine, n, offer);

        exit(itemsToOffer);
    end;

    local procedure ValidateQuantityOffer(var items: Array[50] of Code[20];
        var quantites: Array[50] of integer;
        var entriesType: Array[50] of Integer;
        var unitsOfMeasure: Array[50] of Code[20];
        var usedByMixMatch: Array[50] of Boolean;
        var descriptions: array[50] of Code[100];
        var offerCount: Integer;
        var Response_Text: Text;
        var periodicDiscountLine: Record "LSC Periodic Discount Line";
        i: Integer;
        offer: Code[20])
    var
        j, groups, cantidadEnOferta, cantidadFueraOferta : Integer;
        item: Code[20];
    begin
        groups := quantites[i] div periodicDiscountLine."No. of Items Needed";
        cantidadEnOferta := groups * periodicDiscountLine."No. of Items Needed";
        cantidadFueraOferta := quantites[i] - cantidadEnOferta;
        item := items[i];

        for i := 1 to ArrayLen(items) do begin
            if (items[i] = item) then begin
                quantites[i] := cantidadEnOferta;
                // Si hay sobrante, agregarlo como nueva línea
                if cantidadFueraOferta > 0 then begin
                    for j := 1 to ArrayLen(items) do begin
                        if items[j] = '' then begin
                            items[j] := item;
                            descriptions[j] := descriptions[i];
                            quantites[j] := cantidadFueraOferta;
                            entriesType[j] := entriesType[i];
                            unitsOfMeasure[j] := unitsOfMeasure[i];
                            //AgregarLote(items, Response_Text, j, item);
                            exit;
                        end;
                    end;
                end;
                exit;
            end;
        end;
    end;

    /*local procedure AgregarLote(var items: Array[50] of Code[20]; var Response_Text: Text; Linea: Integer; Item: Code[20]);
    var
        Rprocess: Text;
        JsonObj: JsonObject;
        JsonArray: JsonArray;
        JsonToken: JsonToken;
        JsonItem: JsonObject;
        DueDateText: Text;
        Datef: Date;
        NewJsonInput, lot : text;
        Line: Integer;
        Prod: Code[20];
        i: Integer;
        SaveLot, SaveItem, SaveDueDate : Text;
        SaveLine: Integer;
    begin
        Rprocess := Response_Text;
        Response_Text := '';
        //? Se agrega el lote al JSON
        NewJsonInput := '{"Arreglo":' + Rprocess + '}';
        if JsonObj.ReadFrom(NewJsonInput) then
            if JsonObj.Get('Arreglo', JsonToken) then // Seleccionar el arreglo "Arreglo
                if JsonToken.IsArray then begin  // Verificar que el token es un arreglo y convertirlo
                    JsonArray := JsonToken.AsArray();
                    for i := 1 to ArrayLen(items) do begin
                        if (items[i] <> '') then
                            // Iterar sobre los elementos del arreglo
                            foreach JsonToken in JsonArray do begin
                                if JsonToken.IsObject then begin // Verificar que sea un objeto
                                    JsonItem := JsonToken.AsObject();
                                    if JsonItem.Get('Item', JsonToken) then
                                        Prod := JsonToken.AsValue().AsText();
                                    if JsonItem.Get('Key', JsonToken) then
                                        Line := JsonToken.AsValue().AsInteger();
                                    if JsonItem.Get('Lote', JsonToken) then
                                        lot := JsonToken.AsValue().AsText();
                                    if JsonItem.Get('DueDate', JsonToken) then
                                        DueDateText := JsonToken.AsValue().AsText();
                                    if Prod = Item then begin
                                        SaveLot := lot;
                                        SaveLine := Linea;
                                        SaveItem := Item;
                                        SaveDueDate := DueDateText;
                                    end;
                                    if Item[i] = SaveItem then begin
                                        lot := SaveLot;
                                        Item := SaveItem;
                                        DueDateText := SaveDueDate;
                                    end;
                                    //? Se agrega el lote al JSON
                                    AddLineToJsonArray(items[i], Response_Text, Linea * i, Item, lot, DueDateText);
                                    lot := '';
                                    Item := '';
                                    DueDateText := '';
                                end;
                            end else begin
                            AddLineToJsonArray(items[i], Response_Text, Linea * i, Item, lot, DueDateText);
                        end;
                    end;
                end;
    end;

    procedure AddLineToJsonArray(items: Code[20]; var JsonArrayText: Text; NewKey: Integer; NewItem: Text[20]; NewLote: Text[50]; NewDueDate: Text[30])
    var
        JsonArray: JsonArray;
        NewObject: JsonObject;
    begin
        // Leer el texto JSON en el array
        if JsonArray.ReadFrom(JsonArrayText) then;

        // Crear el nuevo objeto
        Clear(NewObject);
        NewObject.Add('Key', NewKey);
        NewObject.Add('Item', NewItem);
        NewObject.Add('Lote', NewLote);
        NewObject.Add('DueDate', NewDueDate);

        // Agregar al array
        JsonArray.Add(NewObject);

        // Convertir de nuevo a texto
        JsonArray.WriteTo(JsonArrayText);
    end;*/
}
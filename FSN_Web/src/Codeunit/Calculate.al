codeunit 50063 "calculation process"
{
    trigger OnRun()
    begin

    end;

    var
        HospiPOSStartup: Codeunit "LSC Hospitality POS Startup";
        myInt: Integer;
        GlobalCommand: Text[150];
        GlobalReceipt: Code[20];
        GlobalRequest: Text;
        GlobalResponse: Text;
        gText011: Label 'El Club Membresia %1 no tiene configurado Periodo de expiración';
        gText012: Label 'No se puede modificar la tarjeta membresia %1';
        gText013: Label 'Tarjeta %1, en Club %2 dentro de esquema %3 fue registrada exitosamente!';
        gText014: Label 'Error de datos. No existe el contacto %1, no se puede renovar';
        gText015: Label 'Error. No se pudo actualizar el cliente %1.';
        gText016: Label 'Error. No se pudo crear el cliente %1.';
        gText017: Label 'No se puede insertar el cliente en la transaccion. %1';
        gText018: Label 'Error en producto %1 %2';

    procedure CalculationProcess(
    var arrItem: Array[150] of Code[20];
    var arrDescription: Array[150] of Code[100];
    var arrUnitOfMeasure: Array[150] of Code[20];
    var arrQty: Array[150] of Integer;
    var arrEntryType: Array[150] of Integer;
    var arrUnitPriceIncVAT: Array[150] of Decimal;
    var arrDiscount: Array[150] of Decimal;
    var arrAmount: Array[150] of Decimal;
    var arrEffDisc: Array[150] of Decimal;
    var arrEffAmt: Array[150] of Decimal;
    var totalDiscount: Decimal;
    var totalAmount: Decimal;
    var balance: Decimal;
    var balanceVIP: Decimal;
    customerNo: Code[20];
    memberCardNo: Code[20];
    var Response_Text: Text;
    var Inventary: array[150] of Integer
)
    var
        useByMixMatch: array[150] of Boolean;
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
    begin

        //? Eliminar entry type 2
        DeleteEntryType(arrItem, arrDescription, arrUnitOfMeasure, arrQty, arrEntryType, arrUnitPriceIncVAT, arrDiscount, arrAmount, arrEffDisc, arrEffAmt);
        MergeDuplicateLines(arrItem, arrDescription, arrUnitOfMeasure, arrQty, arrEntryType, arrUnitPriceIncVAT, arrDiscount, arrAmount, arrEffDisc, arrEffAmt, Inventary);
        //? Entero maximo posible del lenguaje AL
        INT_MAX := 2147483647;
        if Currency.get('US') then;
        //? Validacion del grupo de descuento del cliente
        if customer.Get(customerNo) then;
        if memberCardNo <> '' then
            discGroup := GetValidCustDiscGroup(memberCardNo)
        else
            discGroup := GetDiscGroupByCustomer(customerNo, customer."Customer Disc. Group");

        if customerNo = '' then
            discGroup := 'WITHOUT_DISCOUNT';

        for i := 1 to ArrayLen(arrItem) do begin
            if arrItem[i] <> '' then
                if arrEntryType[i] = 0 then begin
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
                end;
        end;
        MergeDuplicateLines(arrItem, arrDescription, arrUnitOfMeasure, arrQty, arrEntryType, arrUnitPriceIncVAT, arrDiscount, arrAmount, arrEffDisc, arrEffAmt, Inventary);
    end;

    local procedure DeleteEntryType(var arrItem: Array[150] of Code[20];
        var arrDescription: Array[150] of Code[100];
        var arrUnitOfMeasure: Array[150] of Code[20];
        var arrQty: Array[150] of Integer;
        var arrEntryType: Array[150] of Integer;
        var arrUnitPriceIncVAT: Array[150] of Decimal;
        var arrDiscount: Array[150] of Decimal;
        var arrAmount: Array[150] of Decimal;
        var arrEffDisc: Array[150] of Decimal;
        var arrEffAmt: Array[150] of Decimal)
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
        arrItems: Array[150] of Code[20];
        arrUnitOfMeasure: Array[150] of Code[20];
        arrQty: Array[150] of Integer;
        arrUseByMixMatch: Array[150] of Boolean;
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
        items: array[150] of Code[20];
        quantites: array[150] of Integer;
        unitsOfMeasure: array[150] of Code[20];
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

        var items: array[150] of Code[20];
        var quantites: array[150] of Integer;
        var unitsOfMeasure: array[150] of Code[20];
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

    local procedure ValidateQuantityOffer(var items: Array[150] of Code[20];
        var quantites: Array[150] of integer;
        var entriesType: Array[150] of Integer;
        var unitsOfMeasure: Array[150] of Code[20];
        var usedByMixMatch: Array[150] of Boolean;
        var descriptions: array[150] of Code[100];
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

    procedure getIndex(Arr: Array[150] of Integer; Value: integer): Integer;
    var
        i: Integer;

    begin
        for i := 1 to ArrayLen(Arr) do begin
            if Arr[i] = Value then
                exit(i);
        end;
        exit(0);
    end;

    procedure getIndex(Arr: Array[150] of Code[20]; Value: Code[20]): Integer;
    var
        i: Integer;

    begin
        for i := 1 to ArrayLen(Arr) do begin
            if Arr[i] = Value then
                exit(i);
        end;
        exit(0);
    end;

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

        if MemberScheme.Get(MemberCard."Club Code") then
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

    procedure MergeDuplicateLines(
    var arrItem: Array[150] of Code[20];
        var arrDescription: Array[150] of Code[100];
        var arrUnitOfMeasure: Array[150] of Code[20];
        var arrQty: Array[150] of Integer;
        var arrEntryType: Array[150] of Integer;
        var arrUnitPriceIncVAT: Array[150] of Decimal;
        var arrDiscount: Array[150] of Decimal;
        var arrAmount: Array[150] of Decimal;
        var arrEffDisc: Array[150] of Decimal;
        var arrEffAmt: Array[150] of Decimal;
        var arrInventary: Array[150] of Integer)
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

                        // Sumar cantidades y montos
                        arrQty[i] += arrQty[j];
                        arrAmount[i] += arrAmount[j];
                        if arrAmount[i] <> 0 then
                            Desc := arrAmount[i] / (arrUnitPriceIncVAT[i] * arrQty[i]);
                        arrDiscount[i] := Round(Desc * 100, 0.1);
                        arrInventary[i] += arrInventary[j];
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

    procedure CalcDistance(receiptNo: Code[20]; var store_tmp2: Record "LSC Store" temporary)
    var
        menuLine: Record "LSC POS Menu Line";
        postedDeliveryOrder: Record "LSC Posted Delivery Order";
        posTransaction: Record "LSC POS Transaction";
        wsTable: Record "FSN WebServiceTable";
        parameter: Record "FSN Parameter";
        store_tmp: Record "LSC Store" temporary;
        store: Record "LSC Store";
        storeLink: Record "FSN Store Link";
        hospFunc: Codeunit "LSC Hospitality Functions";
        j, i, prodTimeLength : Integer;
        lat, lon : Decimal;
        position: List of [Text];
        dateTimeIn, timeFrom, timeTo : DateTime;
        ok, error : Boolean;
        errorText: Text;
        DeliveryOrder: Record "LSC Delivery Order";
        openStatus: Option;
        DelStreet: Record "LSC Delivery Street";
    begin
        if DeliveryOrder.Get(receiptNo) then begin
            if DeliveryOrder."FSN Alter Key" <> 0 then begin
                DelStreet.Reset();
                DelStreet.SetRange("FSN Alter Key", DeliveryOrder."FSN Alter Key");
                if not DelStreet.FindFirst() then begin
                    Message('No se encontró la calle de entrega para la orden de entrega %1', DeliveryOrder."Phone No.");
                    exit;
                end;
                if store.Get(DeliveryOrder."Restaurant No.") then;
                store_tmp := store;
                if store_tmp.Insert() then;

            end;
            lat := DelStreet."FSN Latitude";
            lon := DelStreet."FSN Longitude";
            storeLink.Reset();
            storeLink.SetRange(Type, storeLink.Type::StoreSetup);
            if storeLink.Find('-') then
                repeat
                    dateTimeIn := CurrentDateTime;
                    ok := hospFunc.FindProductionTime(
                        storeLink."Parent Code",
                        0,
                        '',
                        dateTimeIn,
                        0,
                        errorText,
                        false,
                        prodTimeLength,
                        timeFrom,
                        timeTo,
                        openStatus
                    );

                    if ok and not store_tmp.Get(storeLink."Parent Code") then begin
                        store_tmp2.Init();
                        store_tmp2."Fraud Sort Field" := GetDistanceGeopraphic(
                            lat,
                            lon,
                            storeLink."Parent Latitude",
                            storeLink."Parent Longitude"
                        );
                        store_tmp2."No." := storeLink."Parent Code";
                        if store_tmp2."Fraud Sort Field" <= 5 then
                            if store_tmp2.Insert() then;
                    end;
                until storeLink.Next() = 0;
        end;
    end;

    procedure XCheckOrderDelivery(pIsTakeaway: Boolean; OrderNo: Code[20];
    var ContactTMP: Record "LSC Delivery Contact Address" temporary;
    var OrderTMP: Record "LSC POS Trans. Line" temporary;
    var POSTransLTMP: Record "LSC POS Trans. Line" temporary;
    DelOrder: Record "LSC Delivery Order")
    var
        StoreTMP: Record "LSC Store" temporary;
        DeliveryStreet_l: Record "LSC Delivery Street";
        DeliveryStreetTMP: Record "LSC Delivery Street" temporary;
        StoreLink_l: Record "FSN Store Link";
        Parameters: Record "FSN Parameter";
        Lat: Decimal;
        Lon: Decimal;
        TextError: Text;
        StringVar: Text;
        RequestItemXML: Text;
        Item_l: Record Item;
        Store_l: Record "LSC Store";
        Text001: Label 'Georeference cant be empty (Latitude, Longitude)';
        Text002: Label 'Must be store for takeaway';
        Text003: Label 'Must be select other store for takeaway';
        Text004: Label 'No suggested stores in the area';
        Text006: Label 'Out of cover';
        Contact: Record "LSC Delivery Contact Address";
        PosTransLine: Record "LSC POS Trans. Line";
    begin
        DeliveryStreetTMP.RESET;
        DeliveryStreetTMP.DELETEALL;
        CLEAR(DeliveryStreetTMP);
        StoreTMP.RESET;
        StoreTMP.DELETEALL;
        CLEAR(StoreTMP);
        CLEAR(TextError);
        CLEAR(StringVar);

        if Parameters.Get('ECOMM', 'XCHECK') then;

        CalcDistance(DelOrder."Order No.", StoreTMP);

        StoreTMP.SETCURRENTKEY("Fraud Sort Field");
        IF StoreTMP.FIND('-') THEN BEGIN
            IF pIsTakeaway THEN
                RequestItemXML := XmlFromItemInventoryTransTMP(POSTransLTMP, StoreTMP, OrderTMP."Store No.")
            ELSE
                RequestItemXML := XmlFromItemInventoryTransTMP(POSTransLTMP, StoreTMP, StoreTMP."No.");


        END ELSE BEGIN
            IF NOT Item_l.GET(Parameters."Value Text 1") THEN//Setup Item
                Item_l.INIT;
            OrderTMP.Number := Item_l."No.";
            OrderTMP."Unit of Measure" := Item_l."Base Unit of Measure";
            OrderTMP."Delivery User ID" := Item_l."No." + Item_l."Base Unit of Measure";
            OrderTMP."Cost Price" := Item_l."LSC Unit Price Incl. VAT";
            OrderTMP."Add. Charge Exists" := TRUE;
            OrderTMP.MODIFY;
        END;
        XCompareInventoryDelivery(RequestItemXML, pIsTakeaway, OrderTMP, ContactTMP, POSTransLTMP);
    end;

    procedure XCompareInventoryDelivery(pRequestXML: Text; pIsTakeaway: Boolean; var pOrderTMP: Record "LSC POS Trans. Line" temporary; var pContactTMP: Record "LSC Delivery Contact Address"; var pPosLineTMP: Record "LSC POS Trans. Line")
    var
        QueryTxt: Text;
        Index: Integer;
        XmlString: Text;
        lText001: Label 'Conection Error DB';
        lText002: Label 'Cant be suggest items';
        POSTransLineTMP: Record "LSC POS Trans. Line" temporary;
        StoreTMP: Record "LSC Store" temporary;
        TextError: Text;
        xmlDocument: DotNet XmlDocument;
        xmlResponse: DotNet XmlDocument;
        xNode: DotNet XmlNode;
        xNodeRes: DotNet XmlNode;
        xChild: DotNet XmlNode;
        xChildFields: DotNet XmlNode;
        WSFunc: Codeunit "LSC WS Functions";
        ResponseNodeList: array[5] of Text[150];
        RequestNodeList: array[3] of Text[150];
        ParentNodeIndex: Integer;
        ParentNodeList: array[5] of Text[150];
        TableNodeList: Record "LSC WS Node Buffer" temporary;
        Response_Code: Code[30];
        Response_Text: Text[1024];
        RequestID: Text[30];
        RecRef: RecordRef;
        RecRefTemp: array[32] of RecordRef;
        FlowFieldBuffer: Record "LSC FlowField Buffer" temporary;
        UpdateFieldList: Record "Field" temporary;
        Req: Text;
        WJSonHeader: Codeunit "FSN Windows Forms NET";
        Odata: Codeunit "FSN OData Conexion";
        FileMgt: Codeunit "File Management";
        FilterString: Text;
        FileSystem: DotNet StreamWriter;
        Parameters: Record "FSN Parameter";
        DistLoc: Code[20];
        SP: Text[250];
        Text006: Label 'Out of cover';
        Url: text;
        PageImagen: Page TextCopy;
    begin
        Clear(DistLoc);
        Clear(SP);
        if Parameters.Get('ECOMM', 'XINVENTORY') then begin
            DistLoc := Parameters."Distribution Location Ext.";
            SP := Parameters.Valor;
        end;

        IF pOrderTMP."Add. Charge Exists" THEN BEGIN
            xCreateDocDefault(xmlResponse, xNodeRes, 'Response', Text006, '0000');  //Hour setup
            xNode := xmlResponse.CreateNode('element', 'Response_Body', '');
            xNodeRes.AppendChild(xNode);

            IF pOrderTMP.FIND('-') THEN BEGIN
                xChild := xmlResponse.CreateNode('element', 'Order', '');
                xNode.AppendChild(xChild);
                xChildFields := xmlResponse.CreateNode('element', WJSonHeader.NameConvert(pOrderTMP.FIELDNAME(pOrderTMP.Description)), '');
                xChildFields.InnerText := STRSUBSTNO('ENVIO PAQUETERIA EN %1 HORAS', FORMAT(48));//Hour setup
                xChild.AppendChild(xChildFields);
                xChildFields := xmlResponse.CreateNode('element', WJSonHeader.NameConvert(pOrderTMP.FIELDNAME(pOrderTMP."Delivery User ID")), '');
                xChildFields.InnerText := pOrderTMP."Delivery User ID";
                xChild.AppendChild(xChildFields);
                xChildFields := xmlResponse.CreateNode('element', WJSonHeader.NameConvert(pOrderTMP.FIELDNAME(pOrderTMP.Number)), '');
                xChildFields.InnerText := pOrderTMP.Number;
                xChild.AppendChild(xChildFields);
                xChildFields := xmlResponse.CreateNode('element', WJSonHeader.NameConvert(pOrderTMP.FIELDNAME(pOrderTMP."Unit of Measure")), '');
                xChildFields.InnerText := pOrderTMP."Unit of Measure";
                xChild.AppendChild(xChildFields);
                xChildFields := xmlResponse.CreateNode('element', WJSonHeader.NameConvert(pOrderTMP.FIELDNAME(pOrderTMP."Cost Price")), '');
                xChildFields.InnerText := FORMAT(pOrderTMP."Cost Price");
                xChild.AppendChild(xChildFields);
                xChildFields := xmlResponse.CreateNode('element', WJSonHeader.NameConvert(pOrderTMP.FIELDNAME(pOrderTMP."Add. Charge Exists")), '');
                xChildFields.InnerText := FORMAT(pOrderTMP."Add. Charge Exists");
                xChild.AppendChild(xChildFields);
            END;

            pPosLineTMP.RESET;
            IF pPosLineTMP.FIND('-') THEN
                REPEAT
                    xChild := xmlResponse.CreateNode('element', 'Lines', '');
                    xNode.AppendChild(xChild);

                    xChildFields := xmlResponse.CreateNode('element', WJSonHeader.NameConvert(pPosLineTMP.FIELDNAME(pPosLineTMP."Delivery User ID")), '');
                    xChildFields.InnerText := pPosLineTMP."Delivery User ID";
                    xChild.AppendChild(xChildFields);
                    xChildFields := xmlResponse.CreateNode('element', WJSonHeader.NameConvert(pPosLineTMP.FIELDNAME(pPosLineTMP.Number)), '');
                    xChildFields.InnerText := pPosLineTMP.Number;
                    xChild.AppendChild(xChildFields);
                    xChildFields := xmlResponse.CreateNode('element', WJSonHeader.NameConvert(pPosLineTMP.FIELDNAME(pPosLineTMP."Unit of Measure")), '');
                    xChildFields.InnerText := pPosLineTMP."Unit of Measure";
                    xChild.AppendChild(xChildFields);
                    xChildFields := xmlResponse.CreateNode('element', WJSonHeader.NameConvert(pPosLineTMP.FIELDNAME(pPosLineTMP."Remaining Quantity")), '');
                    xChildFields.InnerText := FORMAT(pPosLineTMP."Remaining Quantity");
                    xChild.AppendChild(xChildFields);
                    xChildFields := xmlResponse.CreateNode('element', WJSonHeader.NameConvert(pPosLineTMP.FIELDNAME(pPosLineTMP.Quantity)), '');
                    xChildFields.InnerText := FORMAT(pPosLineTMP.Quantity);
                    xChild.AppendChild(xChildFields);
                    xChildFields := xmlResponse.CreateNode('element', WJSonHeader.NameConvert(pPosLineTMP.FIELDNAME(pPosLineTMP.Marked)), '');
                    xChildFields.InnerText := 'true';
                    xChild.AppendChild(xChildFields);

                UNTIL pPosLineTMP.NEXT = 0;

            GlobalResponse := xGetResponseOnly(xmlResponse, 'Response');
            EXIT;
        END;

        xmlDocument := xmlDocument.XmlDocument();
        xmlDocument.LoadXml(pRequestXML);
        xNode := xmlDocument.SelectSingleNode('/Data');
        QueryTxt := xNode.OuterXml();

        IF pIsTakeaway THEN
            QueryTxt := SP + ' ''' + QueryTxt + ''',''' + GlobalCommand + ''',1'
        ELSE
            QueryTxt := SP + ' ''' + QueryTxt + ''',''' + GlobalCommand + ''',0';

        XmlString := SQLCall(DistLoc, QueryTxt);
        GlobalResponse := XmlString;

        Url := GenerateHTML();
        PageImagen.CopyTxt(Url);
        PageImagen.Run();
    end;

    procedure GenerateHTML(): Text
    var
        XmlDoc: DotNet XmlDocument;
        StoreLinksHTML: Text;
        xNodeList: DotNet XmlNodeList;
        xNode: DotNet XmlNode;
        i: Integer;
    begin
        // Cargar el XML desde GlobalResponse
        XmlDoc := XmlDoc.XmlDocument();
        XmlDoc.LoadXml(GlobalResponse);

        StoreLinksHTML := '';
        xNodeList := XmlDoc.SelectNodes('/Response/Response_Body/StoreLinks');
        if not ISNULL(xNodeList) then
            for i := 0 to xNodeList.Count() - 1 do begin
                xNode := xNodeList.Item(i);
                StoreLinksHTML += '<tr>' +
                                  '<td>' + xNode.SelectSingleNode('No_').InnerText + '</td>' +
                                  '<td>' + ConvertDecimal(xNode.SelectSingleNode('Fraud_Sort_Field').InnerText) + '</td>' +
                                  '</tr>';
            end;

        exit(
            '<!DOCTYPE html>' +
            '<html lang="en">' +
            '<head>' +
            '    <meta charset="UTF-8">' +
            '    <meta name="viewport" content="width=device-width, initial-scale=1.0">' +
            '    <title>Salas con inventario disponible</title>' +
            '    <style>' +
            '        body { font-family: Arial, sans-serif; margin: 20px; text-align: center; }' +
            '        table { width: 100%; border-collapse: collapse; margin-top: 20px; }' +
            '        table, th, td { border: 1px solid #ddd; }' +
            '        th, td { padding: 8px; text-align: center; }' +
            '        th { background-color: #0097a2; color: white; }' +
            '    </style>' +
            '</head>' +
            '<body>' +
            '    <table>' +
            '        <tr>' +
            '            <th colspan="2">Salas Sugeridas</th>' +
            '        </tr>' +
            '        <tr>' +
            '            <th>No.</th>' +
            '            <th>KM Distancia</th>' +
            '        </tr>' +
            StoreLinksHTML +
            '    </table>' +
            '</body>' +
            '</html>'
        );
    end;

    local procedure ConvertDecimal(KM: Text): Text
    var
        myInt: Integer;
        KmDecimal: Decimal;
        KMT: Text;
    begin
        if Evaluate(KmDecimal, KM) then
            KMT := Format(KmDecimal);
        exit(kmt);
    end;

    procedure xGetResponseOnly(var xmlDocument: DotNet XmlDocument; xBodyName: Text[150]) Resp: Text
    var
        xRespBody: DotNet XmlNode;
    begin
        xBodyName := '/' + xBodyName;

        xRespBody := xmlDocument.SelectSingleNode(xBodyName);
        Resp := xRespBody.OuterXml;
        EXIT(Resp);
    end;

    procedure SQLCall(pDistribLocation: Code[10]; pQuery: Text) Msg: Text
    var
        SQLRead: Codeunit "FSN SQL Data Reader";
        SqlDataReaderNET: DotNet SqlDataReader;
        QueryTxt: Text;
        Index: Integer;
        StringVal: Text;
        lText001: Label 'Conection Error DB';
        lText002: Label 'Cant be suggest items';
        POSTransLineTMP: Record "LSC POS Trans. Line" temporary;
        TextError: Text;
        xmlDocument: DotNet XmlDocument;
        xNode: DotNet XmlNode;
    begin

        CLEAR(TextError);
        SQLRead.ClearParams();
        SQLRead.SetDistributionLocation(pDistribLocation);
        SQLRead.SetQuery(pQuery);
        SQLRead.SetAction('OPEN');
        COMMIT;
        IF SQLRead.RUN THEN;
        IF NOT SQLRead.IsConnect THEN
            ERROR(lText001);

        SQLRead.SetAction('POST');
        COMMIT;
        IF SQLRead.RUN THEN;

        Index := 0;
        SQLRead.GetDataReader(SqlDataReaderNET);
        IF NOT ISNULL(SqlDataReaderNET) THEN
            WHILE SqlDataReaderNET.Read() AND (Index = 0) DO BEGIN
                Msg := SqlDataReaderNET.Item('Data');
                Index += 1;
            END;

        IF Index = 0 THEN
            TextError := lText002;

        SQLRead.SetAction('CLOSE');
        COMMIT;
        IF SQLRead.RUN THEN;
        SQLRead.ClearParams();

        IF TextError <> '' THEN BEGIN
            xCreateDocDefault(xmlDocument, xNode, 'Data', TextError, '9999');
            Msg := xmlDocument.OuterXml;
        END;
    end;

    procedure XmlFromItemInventoryTransTMP(var pPOSTransLineTMP: Record "LSC POS Trans. Line" temporary; var pStoreTMP: Record "LSC Store" temporary; pStoreDefault: Code[10]): Text
    var
        ItemSetupTMP: Record "FSN Inventory Internal Log" temporary;
        ItemUM: Record "Item Unit of Measure";
        xmlDocument: DotNet XmlDocument;
        xNode: DotNet XmlNode;
        xChildFields: DotNet XmlNode;
        xChild: DotNet XmlNode;
        Attribute: DotNet XmlAttribute;
        WJSonHeader: Codeunit "FSN Windows Forms NET";
        WSFunc: Codeunit "LSC WS Functions";
    begin
        ItemSetupTMP.RESET;
        ItemSetupTMP.DELETEALL;
        CLEAR(ItemSetupTMP);
        IF pPOSTransLineTMP.FIND('-') THEN
            REPEAT
                IF NOT ItemSetupTMP.GET(pPOSTransLineTMP.Number) THEN BEGIN
                    ItemSetupTMP.INIT;
                    ItemSetupTMP."No." := pPOSTransLineTMP.Number;
                    ItemSetupTMP."Qty. per UM" := 0;
                    ItemSetupTMP.INSERT;
                END;
                IF NOT ItemUM.GET(pPOSTransLineTMP.Number, pPOSTransLineTMP."Unit of Measure") THEN BEGIN
                    ItemUM.INIT;
                    ItemUM."Qty. per Unit of Measure" := 1;
                END;
                ItemSetupTMP."Qty. per UM" += pPOSTransLineTMP.Quantity * ItemUM."Qty. per Unit of Measure";
                ItemSetupTMP.MODIFY;

                pPOSTransLineTMP.Counter := 0;
                pPOSTransLineTMP.MODIFY;
            UNTIL pPOSTransLineTMP.NEXT = 0;

        xCreateDocDefault(xmlDocument, xNode, 'Data', '', '0000');
        IF pPOSTransLineTMP.FIND('-') THEN
            REPEAT
                IF NOT ItemSetupTMP.GET(pPOSTransLineTMP.Number) THEN BEGIN
                    ItemSetupTMP.INIT;
                    ItemSetupTMP."Qty. per UM" := 0;
                END;

                pPOSTransLineTMP.Counter := ItemSetupTMP."Qty. per UM";
                pPOSTransLineTMP.MODIFY;

                xChild := xmlDocument.CreateNode('element', 'Lines', '');
                xSetAttributeNode(xChild, WJSonHeader.NameConvert(pPOSTransLineTMP.FIELDNAME(pPOSTransLineTMP.Number)), pPOSTransLineTMP.Number);
                xSetAttributeNode(xChild, WJSonHeader.NameConvert(pPOSTransLineTMP.FIELDNAME(pPOSTransLineTMP."Unit of Measure")), pPOSTransLineTMP."Unit of Measure");
                xSetAttributeNode(xChild, WJSonHeader.NameConvert(pPOSTransLineTMP.FIELDNAME(pPOSTransLineTMP.Counter)), DELCHR(FORMAT(ROUND(pPOSTransLineTMP.Counter, 1)), '=', ','));
                xSetAttributeNode(xChild, WJSonHeader.NameConvert(pPOSTransLineTMP.FIELDNAME(pPOSTransLineTMP."Store No.")), pStoreDefault);
                xNode.AppendChild(xChild);

            UNTIL pPOSTransLineTMP.NEXT = 0;

        IF pStoreTMP.FIND('-') THEN
            REPEAT

                xChild := xmlDocument.CreateNode('element', 'StoreLinks', '');
                xSetAttributeNode(xChild, WJSonHeader.NameConvert(pStoreTMP.FIELDNAME(pStoreTMP."No.")), pStoreTMP."No.");
                xSetAttributeNode(xChild, WJSonHeader.NameConvert(pStoreTMP.FIELDNAME(pStoreTMP."Fraud Sort Field")), DELCHR(FORMAT(ROUND(pStoreTMP."Fraud Sort Field", 0.01)), '=', ','));
                xNode.AppendChild(xChild);
            UNTIL pStoreTMP.NEXT = 0;

        EXIT(xmlDocument.OuterXml);
    end;

    procedure xSetAttributeNode(var xChild: DotNet XmlNode; xNodeName: Text[150]; xInnerText: Text)
    var
        Attribute: DotNet XmlAttribute;
    begin
        Attribute := xChild.OwnerDocument.CreateAttribute(xNodeName);
        Attribute.Value := xInnerText;
        xChild.Attributes.SetNamedItem(Attribute);
    end;

    procedure ClearTableTmp(var pPOSTransLineTMP: Record "LSC POS Trans. Line" temporary)
    begin
        pPOSTransLineTMP.RESET;
        pPOSTransLineTMP.DELETEALL();
        CLEAR(pPOSTransLineTMP);
    end;

    procedure XmlToPOSTransLineTMP(var pPOSTransLineTmp: Record "LSC POS Trans. Line" temporary; pjSonTxt: Text)
    var
        xmlDocument: DotNet XmlDocument;
        xNode: DotNet XmlNode;
        xNodeList: DotNet XmlNodeList;
        xChildNodes: DotNet XmlNodeList;
        xChild: DotNet XmlNode;
        i: Integer;
        j: Integer;
        c: Integer;
        k: Integer;
        Dec_: Decimal;
        Int_: Integer;
        WindowsNet: Codeunit "FSN Windows Forms NET";
    begin
        ClearTableTmp(pPOSTransLineTmp);
        xmlDocument := xmlDocument.XmlDocument();
        xmlDocument.LoadXml(pjSonTxt);
        xNodeList := xmlDocument.SelectNodes('/Data/Lines');
        i := xNodeList.Count();
        j := 0;
        WHILE i > j DO BEGIN
            xNode := xNodeList.Item(j);
            IF NOT ISNULL(xNode) THEN BEGIN
                pPOSTransLineTmp.INIT;
                pPOSTransLineTmp."Receipt No." := 'X';
                pPOSTransLineTmp."Line No." := j;

                xChildNodes := xNode.ChildNodes();
                c := xChildNodes.Count();
                k := 0;
                WHILE c > k DO BEGIN
                    xChild := xChildNodes.Item(k);
                    IF NOT ISNULL(xChild) THEN
                        CASE xChild.Name OF
                            WindowsNet.NameConvert(pPOSTransLineTmp.FIELDNAME(Number)):
                                pPOSTransLineTmp.Number := xChild.InnerText;
                            WindowsNet.NameConvert(pPOSTransLineTmp.FIELDNAME(pPOSTransLineTmp."Unit of Measure")):
                                pPOSTransLineTmp."Unit of Measure" := xChild.InnerText;
                            WindowsNet.NameConvert(pPOSTransLineTmp.FIELDNAME(pPOSTransLineTmp.Quantity)):
                                BEGIN
                                    IF EVALUATE(Dec_, xChild.InnerText) THEN
                                        pPOSTransLineTmp.Quantity := Dec_;
                                END;
                            WindowsNet.NameConvert(pPOSTransLineTmp.FIELDNAME(pPOSTransLineTmp.Marked)):
                                BEGIN
                                    IF EVALUATE(Int_, xChild.InnerText) THEN
                                        IF Int_ = 1 THEN
                                            pPOSTransLineTmp.Marked := TRUE;
                                END;
                        END;
                    k += 1;
                END;
                IF pPOSTransLineTmp.Number <> '' THEN
                    pPOSTransLineTmp.INSERT;

            END;
            j += 1;
        END;
    end;

    procedure xCreateDocDefault(var xmlDocument: DotNet XmlDocument; var xNodeBody: DotNet XmlNode; xBodyName: Text[150]; pRespText: Text; pRespCode: Text[150])
    var
        xChild: DotNet XmlNode;
    begin
        xmlDocument := xmlDocument.XmlDocument();

        xNodeBody := xmlDocument.CreateProcessingInstruction('xml', 'version="1.0" encoding="utf-8" standalone="no"');
        xmlDocument.AppendChild(xNodeBody);

        xNodeBody := xmlDocument.CreateNode('element', xBodyName, '');
        xmlDocument.AppendChild(xNodeBody);
        IF GlobalCommand <> '' THEN BEGIN
            xChild := xmlDocument.CreateNode('element', 'Request_ID', '');
            xChild.InnerText := GlobalCommand;
            xNodeBody.AppendChild(xChild);
        END;
        xChild := xmlDocument.CreateNode('element', 'Response_Text', '');
        xChild.InnerText := pRespText;
        xNodeBody.AppendChild(xChild);
        xChild := xmlDocument.CreateNode('element', 'Response_Code', '');
        xChild.InnerText := pRespCode;
        xNodeBody.AppendChild(xChild);
    end;

    procedure XCreateDefaultResp(pTextError: Text; pCodeError: Text[10]): Text
    var
        xmlDocument: DotNet XmlDocument;
        xNode: DotNet XmlNode;
        xChild: DotNet XmlNode;
    begin
        xCreateDocDefault(xmlDocument, xNode, 'Response', pTextError, pCodeError);
        EXIT(xmlDocument.OuterXml);
    end;

    procedure XmlToDelContactTMP(var pDelContactAddTmp: Record "LSC Delivery Contact Address" temporary; pjSonTxt: Text)
    var
        xmlDocument: DotNet XmlDocument;
        xNode: DotNet XmlNode;
        xNodeList: DotNet XmlNodeList;
        xChildNodes: DotNet XmlNodeList;
        xChild: DotNet XmlNode;
        i: Integer;
        j: Integer;
        c: Integer;
        k: Integer;
        POSTrans: Record "LSC POS Trans. Line";
        WindosFunctNet: Codeunit "FSN Windows Forms NET";
    begin
        pDelContactAddTmp.RESET;
        pDelContactAddTmp.DELETEALL;
        CLEAR(pDelContactAddTmp);

        xmlDocument := xmlDocument.XmlDocument();
        xmlDocument.LoadXml(pjSonTxt);
        xNodeList := xmlDocument.SelectNodes('/Data/Contact');
        i := xNodeList.Count();
        IF i > 0 THEN BEGIN
            xNode := xNodeList.Item(0);
            IF NOT ISNULL(xNode) THEN BEGIN
                pDelContactAddTmp.INIT;

                xChildNodes := xNode.ChildNodes();
                c := xChildNodes.Count();
                k := 0;
                WHILE c > k DO BEGIN
                    xChild := xChildNodes.Item(k);
                    IF NOT ISNULL(xChild) THEN
                        CASE xChild.Name OF
                            WindosFunctNet.NameConvert(pDelContactAddTmp.FIELDNAME(pDelContactAddTmp."Phone No.")):
                                pDelContactAddTmp."Phone No." := xChild.InnerText;
                            WindosFunctNet.NameConvert(pDelContactAddTmp.FIELDNAME(pDelContactAddTmp.Latitude)):
                                pDelContactAddTmp.Latitude := xChild.InnerText;
                            WindosFunctNet.NameConvert(pDelContactAddTmp.FIELDNAME(pDelContactAddTmp.Longitude)):
                                pDelContactAddTmp.Longitude := xChild.InnerText;
                            WindosFunctNet.NameConvert(pDelContactAddTmp.FIELDNAME(pDelContactAddTmp."Post Code")):
                                pDelContactAddTmp."Post Code" := xChild.InnerText;
                        END;
                    k += 1;
                END;
                IF pDelContactAddTmp."Phone No." <> '' THEN
                    pDelContactAddTmp.INSERT;
            END;
        END;
    end;


    procedure XmlToDelOrderTMP(var pOrderTmp: Record "LSC POS Trans. Line" temporary; pjSonTxt: Text)
    var
        xmlDocument: DotNet XmlDocument;
        xNode: DotNet XmlNode;
        xNodeList: DotNet XmlNodeList;
        xChildNodes: DotNet XmlNodeList;
        xChild: DotNet XmlNode;
        i: Integer;
        j: Integer;
        c: Integer;
        k: Integer;
        Dec_: Decimal;
        WindosFunctNet: Codeunit "FSN Windows Forms NET";
    begin
        pOrderTmp.RESET;
        pOrderTmp.DELETEALL;
        CLEAR(pOrderTmp);

        xmlDocument := xmlDocument.XmlDocument();
        xmlDocument.LoadXml(pjSonTxt);
        xNodeList := xmlDocument.SelectNodes('/Data/Order');
        i := xNodeList.Count();
        IF i > 0 THEN BEGIN
            xNode := xNodeList.Item(0);
            IF NOT ISNULL(xNode) THEN BEGIN
                pOrderTmp.INIT;
                pOrderTmp."Receipt No." := 'R';

                xChildNodes := xNode.ChildNodes();
                c := xChildNodes.Count();
                k := 0;
                WHILE c > k DO BEGIN
                    xChild := xChildNodes.Item(k);
                    IF NOT ISNULL(xChild) THEN
                        CASE xChild.Name OF
                            WindosFunctNet.NameConvert(pOrderTmp.FIELDNAME(pOrderTmp."Store No.")):
                                pOrderTmp."Store No." := xChild.InnerText;
                            WindosFunctNet.NameConvert(pOrderTmp.FIELDNAME(pOrderTmp.Amount)):
                                BEGIN
                                    IF EVALUATE(Dec_, xChild.InnerText) THEN
                                        pOrderTmp.Amount := Dec_;
                                END;
                        END;
                    k += 1;
                END;
                IF pOrderTmp."Receipt No." <> '' THEN
                    pOrderTmp.INSERT;
            END;
        END;
    end;

    procedure GetDistanceGeopraphic(lat: Decimal; lon: Decimal; ParentLatitude: Decimal; ParentLongitude: Decimal): Decimal
    var
        pi, dataDiff, _lat, _lon : Decimal;
        math: DotNet MathNet;
    begin
        pi := 3.14159265358979323;

        _lat := (lat - ParentLatitude) * (pi / 180);
        _lon := (lon - ParentLongitude) * (pi / 180);

        lat := lat * (pi / 180);
        ParentLatitude := ParentLatitude * (pi / 180);

        dataDiff := math.Pow(math.Sin(_lat / 2), 2) + math.Cos(lat) * math.Cos(ParentLatitude) * math.Pow(math.Sin(_lon / 2), 2);

        exit(6371 * (2 * math.Atan2(math.Sqrt(dataDiff), math.Sqrt(1 - dataDiff))));
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Controller", 'OnButtonPressed', '', true, true)]
    local procedure "LSC POS Controller_OnButtonPressed"
    (
        var POSMenuLine: Record "LSC POS Menu Line";
        var handled: Boolean
    )
    var
        ZYHyperLink: Page "ZY HyperLink";
        Parameter: Record "FSN Parameter";
        HistoricoHyperLink: Page "FSN Historico HyperLink";
        POSTransaccion: Record "LSC POS Transaction";
        POSTranscCod: Codeunit "LSC POS Transaction";
        POSTransLine: Record "LSC POS Trans. Line";
        TEXT001: Label 'Debe agregar un Cliente para la transacción';
        url: Text;
        CustomerNo: Code[20];
    begin
        if POSMenuLine.Command = 'ITEMTEST' then begin
            if not Parameter.Get('ITEM', 'BUSQUEDA') AND (Parameter.Activo) then
                exit;
            if POSTransaccion.Get(POSTranscCod.GetReceiptNo()) then begin
                if POSTransaccion."Customer No." = '' then begin
                    Message(TEXT001);
                    exit;
                end;
                url := StrSubstNo(Parameter."Web Uri", POSTransaccion."Store No.", POSTransaccion."Receipt No.");
                POSTransLine.Reset();
                POSTransLine.SetRange("Receipt No.", POSTransaccion."Receipt No.");
                POSTransLine.SetRange("POS Terminal No.", POSTransaccion."POS Terminal No.");
                POSTransLine.SetRange("Store No.", POSTransaccion."Store No.");
                POSTransLine.SetRange("Entry Status", POSTransLine."Entry Status"::" ");
                if POSTransLine.FindFirst() then;
                ZYHyperLink.SetRecordP(POSTransaccion);
                ZYHyperLink.InsertRecordLine(POSTransLine);
                ZYHyperLink.SetURL(url);
                ZYHyperLink.Run();
            end;
        end;

        if POSMenuLine.Command = 'FSNHISTORICO' then begin
            if not Parameter.Get('ITEM', 'HISTORICO') AND (Parameter.Activo) then
                exit;
            HistoricoHyperLink.SetURL(Parameter."Web Uri");
            HistoricoHyperLink.Run();
        end;

        if POSMenuLine.Command = 'CLIENTEW' then begin
            if not Parameter.Get('BUSQ', 'CLIETNE') AND (Parameter.Activo) then
                exit;
            if POSTransaccion.Get(POSTranscCod.GetReceiptNo()) then begin
                CustomerNo := (Format(POSTransaccion."Customer No.").Replace('#', '%23'));
                HistoricoHyperLink.SetURL(Parameter."Web Uri" + CustomerNo);
                HistoricoHyperLink.Run();
            end;
        end;

        if POSMenuLine.Command = 'FSNINVENTORYHTML' then
            InventoryLookupLine(POSMenuLine);
    end;


    procedure InventoryLookupLine(pMenuLine: Record "LSC POS Menu Line")
    var
        POSLines: Codeunit "LSC POS Trans. Lines";
        POSLine_l: Record "LSC POS Trans. Line";
        ItemFilt: Record Item;
        InvLoTable: Record "LSC Inventory Lookup Table";
        RecRef: RecordRef;
        POSSESSION: Codeunit "LSC POS Session";
        InventoryHTML: Text;
        Store: Record "LSC Distribution Location";
        Url: Text;
        PageImagen: Page TextCopy;
        THTextVal: Text;
        TitleLabel: Label 'Existencias - %1 - %2';
        POSDataSetUtility: Codeunit "LSC POS DataSet Utility";
        InvLoTableTemp: Record "LSC Inventory Lookup Table" temporary;
        TextDisponibilidad: Text[30];
    begin
        POSLines.GetCurrentLine(POSLine_l);
        if (POSLine_l."Entry Type" = POSLine_l."Entry Type"::Item) then begin
            if ItemFilt.Get(POSLine_l.Number) then begin
                InvLoTable.Reset();
                InvLoTable.SetRange("Item No.", ItemFilt."No.");
                IF InvLoTable.Find('-') THEN
                    repeat
                        if Store.Get(InvLoTable."Store No.") then;
                        Clear(InvLoTableTemp);
                        Clear(TextDisponibilidad);
                        InvLoTableTemp := InvLoTable;
                        RecRef.GETTABLE(InvLoTable);
                        TextDisponibilidad := POSDataSetUtility.CreateNetInventoryCaption(RecRef);
                        InventoryHTML +=
                                    '<tr>' +
                                    '<td>' + Store.Description + '</td>' +
                                    '<td>' + InvLoTable."Store No." + '</td>' +
                                    '<td>' + Format(InvLoTable."Item No.") + '</td>' +
                                    '<td>' + TextDisponibilidad + '</td>' +
                                    '<td>' + Format(InvLoTable."Net Inventory") + '</td>';
                        InventoryHTML += '</tr>';
                    //end;
                    until InvLoTable.Next() = 0;

                THTextVal := '<tr>' +
                            '<th>Sucursal</th>' +
                            '<th>No. Tienda</th>' +
                            '<th>No. Producto</th>' +
                            '<th>Disponibilidad</th>' +
                            '<th>Inventario Neto</th>' +
                            '</tr>';


                Url := GenerateHTML(InventoryHTML, THTextVal, StrSubstNo(TitleLabel, POSLine_l.Number, POSLine_l.Description));

                PageImagen.CopyTxt(Url);
                PageImagen.Run();
                EXIT;
            end;
        end;
    end;

    procedure GenerateHTML(TDText: Text; THText: Text; Title: text): Text
    begin


        exit(
            '<!DOCTYPE html>' +
            '<html lang="en">' +
            '<head>' +
            '    <meta charset="UTF-8">' +
            '    <meta name="viewport" content="width=device-width, initial-scale=1.0">' +
            '    <title>Salas con inventario disponible</title>' +
            '   <style> ' +
            '       .scrollable-table {' +
            '           width: 100%;' +
            '           max-height: 400px;' +
            '           overflow-y: auto;' +
            '           border: 1px solid #ccc;' +
            '       }' +

            /*'         .table-title {' +
            '            background-color: #0097a2;' +
            '            padding: 10px;' +
            '            font-size: 25px;' +
            '            font-weight: bold;' +
            '            color: white;' +
            '            text-align: center;' +
            '        }' +*/


            '       table {' +
            '           width: 100%;' +
            '           border-collapse: collapse;' +
            '       }' +

            '       th, td {' +
            '           padding: 8px;' +
            '           border: 1px solid #999;' +
            '           text-align: center;' +
            '           z-index: 0;' +
            '       }' +

             '       .table-title {' +
             '           position: sticky;' +
             '           top: 0;' +
             '           background-color: #0097a2;' +
             '           padding: 8px;' +
             '           font-size: 15px;' +
             '           font-weight: bold;' +
             '           color: white;' +
             '           z-index: 0;' +
             '           border-bottom: 1px solid #ccc;' +
             '       }' +

            '        thead th {' +
            '           position: sticky;' +
             '           top: 35px;' +
             '           background-color: #0097a2;' +
             '           padding: 8px;' +
             '           font-size: 15px;' +
             '           font-weight: bold;' +
             '           color: white;' +
             '           z-index: 0;' +
             '           border-bottom: 1px solid #ccc;' +
            '        }' +

            '        body { font-family: Arial, sans-serif; margin: 20px; text-align: center; }' +
            '        caption, strong, { background-color: #0097a2; color: white; padding: 8px; border: 1px solid #999; }' +
            '   </style>' +
            '</head>' +
            '<body>' +
            '   <div class="scrollable-table">' +
            '   <div class="table-title">' + Title + '</div>' +
            '        <table>' +
            '           <thead>' +
                           THText +
            '           </thead>' +
            '          <tbody>' + TDText +
            '          </tbody>' +
            '       </table>' +
            '   </div>' +
            '</body>' +
            '</html>'
        );
    end;

    procedure GetGlobalCommand(Command: Text[150])
    var
        myInt: Integer;
    begin
        GlobalCommand := Command;
    end;

    procedure InsertCliente(JsonObj: JsonObject)
    var
        myInt: Integer;
        clientObj: JsonObject;
        tmpCodCliente, tmpCodClienteSe : Text;
        jToken: JsonToken;
        Beneficiary: Text;
        nameComodin: Text;
        CorreoComodin: Text;
        menuLine: Record "LSC POS Menu Line";
        LSC_POS_Transaction: Codeunit "LSC POS Transaction";
        MemberShip: Code[20];
    begin
        if JsonObj.Get('primary', jToken) then begin
            if not jToken.AsValue().IsNull then
                tmpCodCliente := jToken.AsValue().AsText()
            else
                exit;
        end else
            exit;

        if JsonObj.Get('primaryMembership', jToken) then begin
            if not jToken.AsValue().IsNull then
                MemberShip := jToken.AsValue().AsText();
        end;

        if JsonObj.Get('secundary', jToken) then
            if not jToken.AsValue().IsNull then begin
                tmpCodClienteSe := jToken.AsValue().AsText();
                if tmpCodClienteSe <> '' then
                    saveSubClient(tmpCodClienteSe);
            end;

        if JsonObj.Get('beneficiary', jToken) then
            if not jToken.AsValue().IsNull then begin
                Beneficiary := jToken.AsValue().AsText();
                CreateBenefi(Beneficiary);
            end;

        if JsonObj.Get('comodin', jToken) then begin
            if not jToken.IsObject() then
                exit;

            clientObj := jToken.AsObject();
            if clientObj.Get('name', jToken) then
                if not jToken.AsValue().IsNull then
                    nameComodin := jToken.AsValue().AsText();
            if clientObj.Get('email', jToken) then
                if not jToken.AsValue().IsNull then
                    CorreoComodin := jToken.AsValue().AsText();

            ClientGenericSave(nameComodin, CorreoComodin);
        end;
        InserCliente(tmpCodCliente, memberShip);
    end;

    local procedure CreateBenefi(beneficiaryName: Text[86])
    var
        myInt: Integer;
        transLine: Record "lsc pos trans. line";
        posTrans: Codeunit "LSC POS Transaction";
        session: Codeunit "LSC POS Session";
    begin
        transLine.Init();
        transLine."Store No." := session.StoreNo();
        transLine."POS Terminal No." := session.TerminalNo();
        transLine."Receipt No." := posTrans.GetReceiptNo();
        transLine."Line No." := 41;
        transLine."Entry Status" := transLine."Entry Status"::" ";
        transLine."Entry Type" := transLine."Entry Type"::FreeText;
        transLine.Description := 'BENEFICIARIO: ' + beneficiaryName;
        transLine."Quantity" := 1;
        if not transLine.Insert(true) then
            transLine.Modify(true);

    end;

    local procedure InserCliente(Cliente: Code[20]; Membresia: text[20])
    var
        myInt: Integer;
        MemberAcc: Record "LSC Member Account";
        MemberShip: Record "LSC Membership Card";
        tmpCodCliente: Text;
        menuLine: Record "LSC POS Menu Line";
        LSC_POS_Transaction: Codeunit "LSC POS Transaction";
        Postransaction: Record "LSC POS Transaction";
        Meme: Text[20];
        PTL: Record "LSC POS Trans. Line";
        PT: Record "LSC POS Transaction";
        POSTransactionEvents: Codeunit "LSC POS Transaction Events";
        Ok: Boolean;
        MembershipCard_TEMP: Record "LSC Membership Card" temporary;
        MemberAccount_gTEMP: Record "LSC Member Account" temporary;
        MemberContact_gTEMP: Record "LSC Member Contact" temporary;
        Handled: Boolean;
    begin
        PTL.Reset();
        PTL.SetRange("Receipt No.", LSC_POS_Transaction.GetReceiptNo());
        PTL.SetRange("Entry Type", PTL."Entry Type"::FreeText);
        PTL.SetRange("Text Type", PTL."Text Type"::"Member Text");
        PTL.DeleteAll();

        menuLine.Init();
        menuLine.Command := 'SELECTCUST';
        menuLine.Parameter := Cliente;
        LSC_POS_Transaction.run(menuLine);
        if Membresia <> '' then begin
            MembershipCard_TEMP.Init();
            MembershipCard_TEMP."Card No." := Membresia;
            MembershipCard_TEMP.Insert();
            IF PT.Get(LSC_POS_Transaction.GetReceiptNo()) THEN begin
                POSTransactionEvents.OnBeforeCheckMemberCard(PT, MemberAccount_gTEMP, MemberContact_gTEMP, MembershipCard_TEMP, Handled);
                PT."Member Card No." := Membresia;
                PT."Starting Point Balance" := MemberAccount_gTEMP.TotalRemainingPointsInt;
                PT.Modify(true);
            end;
        end else begin
            IF PT.Get(LSC_POS_Transaction.GetReceiptNo()) THEN begin
                PT."Member Card No." := '';
                PT."Starting Point Balance" := 0;
                PT.Modify(true);
            end;
        end;
        HospiPOSStartup.DirectEdit(true);
    end;

    local procedure DeletCustomerL(POSTransaction: Record "LSC POS Transaction")
    var
        myInt: Integer;
        POSTransLine: Record "LSC POS Trans. Line";
    begin
        POSTransLine.Reset();
        POSTransLine.SetRange("Receipt No.", POSTransaction."Receipt No.");
        POSTransLine.SetRange("Entry Type", POSTransLine."Entry Type"::FreeText);
        POSTransLine.SetFilter("Text Type", '=%1|%2', POSTransLine."Text Type"::"Cust. Text", POSTransLine."Text Type"::"Member Text");
        if POSTransLine.Find('-') then begin
            repeat
                if POSTransLine."Card/Customer/Coup.Item No" <> '' then
                    POSTransLine.Delete();
                Commit();
            until POSTransLine.Next() = 0;
        end;
    end;

    local procedure saveSubClient(tmpCodClienteSe: Code[20])
    var
        infocode: Record "LSC POS Trans. Infocode Entry";
        posTransaction: Codeunit "LSC POS Transaction";
        session: Codeunit "LSC POS Session";
    begin
        DeleteInfo(40);
        infocode.Init();
        infocode."Receipt No." := posTransaction.GetReceiptNo();
        infocode."Transaction Type" := 0;
        infocode."Line No." := 40;
        infocode.Infocode := 'TEXT';
        infocode.Information := tmpCodClienteSe;
        infocode."POS Terminal No." := session.TerminalNo();
        infocode."Store No." := session.StoreNo();
        infocode.Date := Today();
        infocode.Time := Time();
        infocode."Staff ID" := session.StaffID();

        if not infocode.Insert(true) then
            infocode.Modify(true);
    end;

    local procedure DeleteInfo(LineNo: Integer)
    var
        DeleteInfoc: Record "LSC POS Trans. Infocode Entry";
        posTransaction: Codeunit "LSC POS Transaction";
        session: Codeunit "LSC POS Session";
    begin
        DeleteInfoc.Reset();
        DeleteInfoc.SetRange("Receipt No.", posTransaction.GetReceiptNo());
        DeleteInfoc.SetRange("POS Terminal No.", session.TerminalNo());
        DeleteInfoc.SetRange("Store No.", session.StoreNo());
        if LineNo = 40 then
            DeleteInfoc.SetFilter("Line No.", '48|49')
        else
            DeleteInfoc.SetRange("Line No.", LineNo);
        if DeleteInfoc.FindSet() then begin
            repeat
                DeleteInfoc.Delete(true);
            until DeleteInfoc.Next() = 0;
        end;
    end;

    local procedure ClientGenericSave(name: Text[100]; email: Text[100])
    var
        infocode: Record "LSC POS Trans. Infocode Entry";
        transLine: Record "LSC POS Trans. Line";
        posTransaction: Codeunit "LSC POS Transaction";
        session: Codeunit "LSC POS Session";
    begin
        DeleteInfo(48);
        infocode.Init();
        infocode."Receipt No." := posTransaction.GetReceiptNo();
        infocode."Transaction Type" := 0;
        infocode."Line No." := 48;
        infocode.Infocode := 'TEXT';
        infocode.Information := name;
        infocode."POS Terminal No." := session.TerminalNo();
        infocode."Store No." := session.StoreNo();
        infocode.Date := Today();
        infocode.Time := Time();
        infocode."Staff ID" := session.StaffID();

        if not infocode.Insert(true) then
            infocode.Modify(true);

        infocode.Init();
        infocode."Receipt No." := posTransaction.GetReceiptNo();
        infocode."Transaction Type" := 0;
        infocode."Line No." := 49;
        infocode.Infocode := 'TEXT';
        infocode.Information := email;
        infocode."POS Terminal No." := session.TerminalNo();
        infocode."Store No." := session.StoreNo();
        infocode.Date := Today();
        infocode.Time := Time();
        infocode."Staff ID" := session.StaffID();

        if not infocode.Insert(true) then
            infocode.Modify(true);

        if name <> '' then begin
            transLine.Reset();
            transLine.SetRange("Receipt No.", posTransaction.GetReceiptNo());
            transLine."Store No." := session.StoreNo();
            transLine."POS Terminal No." := session.TerminalNo();
            transLine.SetRange("Entry Type", transLine."Entry Type"::FreeText);
            transLine.SetRange("Text Type", transLine."Text Type"::"Cust. Text");
            if transLine.FindFirst then begin
                transLine.Description := 'Clie: ' + name;
                transLine.Modify(true);
            end;
        end;

        transLine.Reset();
        transLine.SetRange("Receipt No.", posTransaction.GetReceiptNo());
        transLine.SetRange("POS Terminal No.", session.TerminalNo());
        transLine.SetRange("Entry Status", transLine."Entry Status"::" ");
    end;



    procedure ValidateCustome(JsonObj: JsonObject)
    var
        StoreNo: Code[10];
        _POSTerminal: Code[10];
        _Code: Code[20];
        _Name: Text[50];
        _DUI: Code[20];
        _TaxID: Integer;
        _Phone: Text[30];
        _Phone_2: Text[20];
        _Birthday: Date;
        _ClientType: integer;
        _Gender: integer;
        _Email: Text[80];
        _Address: Text[250];
        _City: Text[30];
        _NIT: Text[20];
        _NRC: Text[30];
        _Giro: Text[120];
        _ExtrangeroNo_: Code[20];
        _Action: integer;
        _Trigger: Boolean;
        clientObj: JsonObject;
        tmpText: Text;
        jToken, token : JsonToken;
        PosTransaction: Record "LSC POS Transaction";
        LSC_POS_Transaction: Codeunit "LSC POS Transaction";
        CustCreateNewOk: Code[20];
        menuLine: Record "LSC POS Menu Line";
        Cliente: Record Customer;
    begin
        // Extraer el objeto client
        if JsonObj.Get('client', token) then begin
            if not token.IsObject() then
                exit;
            clientObj := token.AsObject();

            if clientObj.Get('no', jToken) then
                if not jToken.AsValue().IsNull then
                    _Code := jToken.AsValue().AsText();

            if _Code = '' then
                _Action := 1
            else
                _Action := 2;

            if _Action = 1 then begin
                if Cliente.Get(_Code) then begin
                    if not isEditableCustomer(Cliente) then begin
                    end;
                end;
            end;

            PosTransaction.RESET;
            if PosTransaction.Get(LSC_POS_Transaction.GetReceiptNo()) then begin
                _POSTerminal := PosTransaction."POS Terminal No.";
                StoreNo := PosTransaction."Store No.";
            end else begin
                _POSTerminal := '';
                StoreNo := '';
            end;

            if clientObj.Get('name', jToken) then
                if not jToken.AsValue().IsNull then
                    _Name := jToken.AsValue().AsText();

            if clientObj.Get('fsnDui', jToken) then
                if not jToken.AsValue().IsNull then
                    _DUI := jToken.AsValue().AsText();

            if clientObj.Get('fsnForeignDocument', jToken) then
                if not jToken.AsValue().IsNull then
                    _ExtrangeroNo_ := jToken.AsValue().AsText();

            if clientObj.Get('vatDteTaxIdType', jToken) then
                if not jToken.AsValue().IsNull then
                    _TaxID := jToken.AsValue().AsInteger();

            if clientObj.Get('fsnPhone2', jToken) then
                if not jToken.AsValue().IsNull then
                    _Phone_2 := jToken.AsValue().AsText();

            if clientObj.Get('fsnPhone', jToken) then
                if not jToken.AsValue().IsNull then
                    _Phone := jToken.AsValue().AsText();

            if clientObj.Get('fsnBirthday', jToken) then
                if not jToken.AsValue().IsNull then begin
                    tmpText := jToken.AsValue().AsText();
                    if tmpText <> '' then
                        Evaluate(_Birthday, tmpText);
                end;
            if clientObj.Get('fsnCustomerType', jToken) then
                if not jToken.AsValue().IsNull then
                    Evaluate(_ClientType, jToken.AsValue().AsText());
            if clientObj.Get('fsnGender', jToken) then
                if not jToken.AsValue().IsNull then begin
                    tmpText := jToken.AsValue().AsText();
                    if tmpText = 'HOMBRE' then
                        _Gender := 1
                    else
                        _Gender := 2;
                end;
            if clientObj.Get('email', jToken) then
                if not jToken.AsValue().IsNull then
                    _Email := jToken.AsValue().AsText();

            if clientObj.Get('address', jToken) then
                if not jToken.AsValue().IsNull then
                    _Address := jToken.AsValue().AsText();
            if clientObj.Get('postCode', jToken) then
                if not jToken.AsValue().IsNull then
                    _City := jToken.AsValue().AsText();
            if clientObj.Get('vatRegistrationNo', jToken) then
                if not jToken.AsValue().IsNull then
                    _NIT := jToken.AsValue().AsText();
            if clientObj.Get('fsnNrc', jToken) then
                if not jToken.AsValue().IsNull then
                    _NRC := jToken.AsValue().AsText();
            if clientObj.Get('dteActivityCode', jToken) then
                if not jToken.AsValue().IsNull then
                    _Giro := jToken.AsValue().AsText();

            CustCreateNewOk := CustomerManagement(StoreNo, _POSTerminal, _Code, _Name, _DUI, _TaxID, _Phone, _Phone_2, _Birthday, _ClientType, _Gender, _Email, _Address, _City, _NIT, _NRC, _Giro, _ExtrangeroNo_, _Action, _Trigger);
            if CustCreateNewOk = '' then
                exit;
            InserCliente(CustCreateNewOk, '');
        end else
            ValidateSecundary(JsonObj);
    end;

    local procedure ValidateSecundary(JsonObj: JsonObject)
    var
        myInt: Integer;
        jToken: JsonToken;
        ClienteP, ClienteS : Code[20];
        CJsonObj: JsonObject;
        Customer: Record Customer;
        menuLine: Record "LSC POS Menu Line";
        LSC_POS_Transaction: Codeunit "LSC POS Transaction";
    begin
        if JsonObj.Get('primary', jToken) then
            if not jToken.AsValue().IsNull then
                ClienteP := jToken.AsValue().AsText();

        if JsonObj.Get('secondary', jToken) then
            if jToken.IsObject then begin
                CJsonObj := jToken.AsObject();

                if CJsonObj.Get('no', jToken) then
                    if not jToken.AsValue().IsNull then
                        ClienteS := jToken.AsValue().AsText();

                if Customer.Get(ClienteS) then begin
                    if CJsonObj.Get('name', jToken) then
                        if not jToken.AsValue().IsNull then
                            if Customer.Name <> jToken.AsValue().AsText() then
                                Customer.Name := jToken.AsValue().AsText();

                    if CJsonObj.Get('giro', jToken) then
                        if not jToken.AsValue().IsNull then
                            if Customer."DTE Activity Code" <> jToken.AsValue().AsText() then
                                Customer."DTE Activity Code" := jToken.AsValue().AsText();

                    if CJsonObj.Get('direccion', jToken) then
                        if not jToken.AsValue().IsNull then
                            if Customer.Address <> jToken.AsValue().AsText() then
                                Customer.Address := jToken.AsValue().AsText();

                    if CJsonObj.Get('dui', jToken) then
                        if not jToken.AsValue().IsNull then
                            if Customer."FSN DUI" <> jToken.AsValue().AsText() then
                                Customer."FSN DUI" := jToken.AsValue().AsText();

                    if CJsonObj.Get('telefono', jToken) then
                        if not jToken.AsValue().IsNull then
                            if Customer."Phone No." <> jToken.AsValue().AsText() then
                                Customer."Phone No." := jToken.AsValue().AsText();

                    if CJsonObj.Get('nrc', jToken) then
                        if not jToken.AsValue().IsNull then
                            if Customer."FSN NRC" <> jToken.AsValue().AsText() then
                                Customer."FSN NRC" := jToken.AsValue().AsText();

                    if CJsonObj.Get('nit', jToken) then
                        if not jToken.AsValue().IsNull then
                            if Customer."VAT Registration No." <> jToken.AsValue().AsText() then
                                Customer."VAT Registration No." := jToken.AsValue().AsText();
                    Customer.Modify(true);
                    saveSubClient(ClienteS);
                    InserCliente(ClienteP, '');
                end;
            end;
    end;

    local procedure isEditableCustomer(Customer: Record Customer): Boolean
    var
        attribute: Record "LSC Attribute Value";
    begin
        attribute.SetRange("Attribute Code", 'CLIENTES');
        attribute.SetRange("Link Type", attribute."Link Type"::Customer);
        attribute.SetRange("Link Field 1", Customer."No.");
        attribute.SetRange("Attribute Value", 'NO EDITABLE');
        if attribute.FindSet() then
            exit(false);

        exit(true);
    end;

    procedure CustomerManagement
   (
       _StoreNo: Code[10];
       _POSTerminal: Code[10];
       var _Code: Code[20];
       _Name: Text[50];
       _DUI: Code[20];
       _TaxID: Integer;
       _Phone: Text[30];
       _Phone_2: Text[20];
       _Birthday: Date;
       _ClientType: integer;
       _Gender: integer;
       _Email: Text[80];
       _Address: Text[250];
       _City: Text[30];
       _NIT: Text[20];
       _NRC: Text[30];
       _Giro: Text[120];
       _ExtrangeroNo_: Code[20];
       _Action: integer;
       _Trigger: Boolean
   ) CustCreateNewOk: Code[20]
    var
        PAGECustomerCard: Page "Customer Card";
        PosFuncProfile: Record "LSC POS Func. Profile";
        POSTerminalREC: Record "LSC POS Terminal";
        POSStoreREC: Record "LSC Store";
        CustomerDefault, gCustomer : Record Customer;
        postcode: Record "Post Code";
        RestricOption_: Option Normal,NameOnly,ExcpName,All;
        FunctionalityProfile: Code[10];
        lText001: Label 'Perfil Funcionalidad no existe para Tienda %1 - Terminal %2';
        lText002: Label 'Perfil Funcionalidad no existe %1';
        lText003: Label 'Nada que hacer';
        lText004: Label 'Cliente por defecto no configurado en Perfil Funcionalidad %1';
        lText005: Label 'Cliente configurado en perfil funcionalidad ID %1 no existe';
        lText006: Label 'Cliente ID %1 no existe';
        lText007: Label 'Cliente modificado con exito!';
        lText008: Label 'Cliente registrado con exito!';
        lText009: Label 'El tipo de cliente solo puede ser Persona (0) ó Empresa (1). Esto es un error de programación.';
        lText010: Label 'El Genero solo puede ser Masculino(1) ó Femenino(2) o bien ninguno(0).';
    begin

        GLOBALLANGUAGE(2058);
        FunctionalityProfile := '';
        Clear(PosFuncProfile);
        Clear(gCustomer);

        if not (_Action in [1, 2]) then
            exit('');

        if _Action = 1 then begin
            FunctionalityProfile := '#FASANI';


            if not PosFuncProfile.Get(FunctionalityProfile) then begin
                Message(STRSUBSTNO(lText002, FunctionalityProfile));
                exit('');
            end;

            if PosFuncProfile."New Customer Defaults" = '' then begin
                Message(STRSUBSTNO(lText004, FunctionalityProfile));
                exit('');
            end;

            if not CustomerDefault.Get(PosFuncProfile."New Customer Defaults") then begin
                Message(STRSUBSTNO(lText005, FunctionalityProfile));
                exit('');
            end;

            if _Trigger then begin//For Custom New
                if not CustomerValidateData(PosFuncProfile."New Customer Defaults", _DUI, _NIT, _NRC, _ExtrangeroNo_, _Giro, _Birthday,
                  _ClientType, TRUE, RestricOption_) then
                    EXIT('');
            END;
        END ELSE begin
            if not gCustomer.Get(_Code) then begin
                Message(STRSUBSTNO(lText006, _Code));
                EXIT('');
            END;
            if _Trigger then begin//For Custom Edit
                if not CustomerValidateData(_Code, _DUI, _NIT, _NRC, _ExtrangeroNo_, _Giro, _Birthday, _ClientType, FALSE,
                   RestricOption_) then
                    EXIT('');
            END;
        END;
        COMMIT;
        gCustomer.LOCKTABLE;

        if _Action = 2 then
            gCustomer.Get(_Code)
        ELSE begin
            gCustomer.init();
            gCustomer := CustomerDefault;
        END;

        if not (RestricOption_ in [RestricOption_::ExcpName, RestricOption_::All]) then
            gCustomer.VALIDATE(Name, UPPERCASE(_Name));

        if not (RestricOption_ in [RestricOption_::NameOnly, RestricOption_::All]) then begin
            gCustomer."FSN DUI" := _DUI;
            case _TaxID of
                36:
                    gCustomer."DTE Tax ID Type" := gCustomer."DTE Tax ID Type"::NIT;
                13:
                    gCustomer."DTE Tax ID Type" := gCustomer."DTE Tax ID Type"::DUI;
                37:
                    gCustomer."DTE Tax ID Type" := gCustomer."DTE Tax ID Type"::Otros;
                3:
                    gCustomer."DTE Tax ID Type" := gCustomer."DTE Tax ID Type"::Pasaporte;
                2:
                    gCustomer."DTE Tax ID Type" := gCustomer."DTE Tax ID Type"::"Carnet de Residente";
            end;
            gCustomer."Phone No." := _Phone;
            gCustomer."Telex No." := _Phone_2;
            if DATE2DMY(_Birthday, 3) = 1753 then
                gCustomer."FSN Birthday" := 0D
            ELSE
                gCustomer."FSN Birthday" := _Birthday;
            case _ClientType of
                0:
                    gCustomer."FSN Customer Type" := gCustomer."FSN Customer Type"::Person;
                1:
                    gCustomer."FSN Customer Type" := gCustomer."FSN Customer Type"::Company;
            end;
            case _Gender of
                0:
                    gCustomer."FSN Gender" := gCustomer."FSN Gender"::" ";
                1:
                    gCustomer."FSN Gender" := gCustomer."FSN Gender"::Male;
                2:
                    gCustomer."FSN Gender" := gCustomer."FSN Gender"::Female;

            end;
            gCustomer."E-Mail" := _Email;
            gCustomer.Address := _Address;
            postcode.SetRange(Code, _City);
            if postcode.FindFirst then
                gCustomer.Validate("Post Code", postcode.Code);
            gCustomer."VAT Registration No." := _NIT;
            gCustomer."FSN NRC" := _NRC;
            if _Giro <> '' then
                gCustomer.Validate("DTE Activity Code", _Giro);

            gCustomer."FSN NRC Description" := CopyStr(gCustomer."DTE Active Description", 1, 100);
            gCustomer."FSN Foreign document" := _ExtrangeroNo_;
        END;

        if _Action = 1 then begin

            gCustomer.VALIDATE(gCustomer."No.", '');
            gCustomer."invoice Disc. Code" := gCustomer."No.";
            if not gCustomer.insert(true) then begin
                Message(STRSUBSTNO(gText016, System.GetLastErrorText()));
                EXIT('');
            END;

        END ELSE
            if not gCustomer.MODifY(TRUE) then begin
                Message(STRSUBSTNO(gText015, System.GetLASTERRorTEXT));
                EXIT('');
            END;
        EXIT(gCustomer."No.");
    end;

    procedure CustomerValidateData
   (
       _Code: Code[20];
       DUI: Code[20];
       NIT: Text[20];
       NRC: Text[30];
       NoExtrangero: Code[20];
       Giro: Text[120];
       BirthDay: Date;
       ClientType: integer;
       IsNew: Boolean;
       var RestricOption_: Option Normal,NameOnly,ExcpName,All
   ) CustDataOk: Boolean
    var
        RegEx: DotNet Regex;
        Customer_l: Record Customer;
        FASANIServerUtil: Codeunit "FSN Utility";
        lText001: Label 'Cliente %1 tiene edicion restringida. %2';
        lText002: Label 'Solo nombre es editable';
        lText003: Label 'Nombre no es editable';
        lText004: Label 'Todo bloqueado';
        Response_Text: Text;
    begin
        Customer_l.Get(_Code);
        Customer_l."FSN DUI" := DUI;
        Customer_l."VAT Registration No." := NIT;
        Customer_l."FSN NRC" := NRC;
        Customer_l."FSN NRC Description" := Giro;
        Customer_l."FSN Foreign document" := NoExtrangero;

        Customer_l."FSN Birthday" := BirthDay;
        if ClientType = 1 then
            Customer_l."FSN Customer Type" := Customer_l."FSN Customer Type"::Company
        ELSE
            Customer_l."FSN Customer Type" := Customer_l."FSN Customer Type"::Person;

        if not FASANIServerUtil.ValidateExtraCustomer('', FALSE, IsNew, Customer_l, Response_Text, RestricOption_) then begin
            CLEAR(Customer_l);
            EXIT(FALSE);
        END;

        CASE RestricOption_ OF
            RestricOption_::NameOnly:
                Message(STRSUBSTNO(lText001, Customer_l."No.", lText002));
            RestricOption_::ExcpName:
                Message(STRSUBSTNO(lText001, Customer_l."No.", lText003));
            RestricOption_::All:
                Message(STRSUBSTNO(lText001, Customer_l."No.", lText004));
        END;

        CLEAR(Customer_l);

        EXIT(TRUE);
    end;

    //se tiene que comentar el evento OnAfterInsertItemLine de la codeunit inventory mgt de extension callcenter
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Transaction Events", 'OnAfterInsertItemLine', '', true, true)]
    local procedure "LSC POS Transaction Events_OnAfterInsertItemLine"
(
var POSTransaction: Record "LSC POS Transaction";
var POSTransLine: Record "LSC POS Trans. Line";
var CurrInput: Text
)
    var
        XMLRequest: Text;
        XMLResponse: Text;
        RequestID: Text[150];
        PosMenuLineTemp: Record "LSC POS Menu Line";
        Processed: Boolean;
        MsgResult: Text;
        FSNUtility: Codeunit "FSN Utility";
        pg: page "PREFACTURA CC";
    begin

        if (POSTransLine."Entry Type" = POSTransLine."Entry Type"::Item) AND (POSTransLine.Number <> 'A70107') THEN BEGIN
            RequestID := 'FSNCC';
            Processed := false;
            FSNUtility.InvokeGlobalChannel(XMLRequest, XMLResponse, RequestID, PosMenuLineTemp, Processed, MsgResult);
            IF Processed THEN begin
                if POSTransLine."Entry Type" = POSTransLine."Entry Type"::Item then begin
                    pg.RunProcessLokkupInv(POSTransLine);
                end;
            end;
        end;
    END;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"FSN Utility", 'OnInvokeGlobalChannelEvent', '', true, true)]
    local procedure "FSN Utility_OnInvokeGlobalChannelEvent"
    (
        var XMLRequest: Text;
        var XMLResponse: Text;
        var RequestID: Text[150];
        var POSMenuLine: Record "LSC POS Menu Line";
        var Processed: Boolean;
        var MsgResult: Text
    )
    var
        Parameter: Record "FSN Parameter";
        HistoricoHyperLink: Page "FSN Historico HyperLink";
    begin
        if RequestID = 'DEL-HISTORICO' then begin
            if not Parameter.Get('ITEM', 'HISTORICO') AND (Parameter.Activo) then
                exit;
            IF XMLResponse = '' then
                HistoricoHyperLink.SetURL(Parameter."Web Uri")
            else
                HistoricoHyperLink.SetURL(XMLResponse);
            HistoricoHyperLink.Run();
        end;
    end;
}
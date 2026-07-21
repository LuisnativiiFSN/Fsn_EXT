page 50104 "PREFACTURA CC"
{
    ApplicationArea = All;
    PageType = List;
    UsageCategory = Administration;
    SourceTable = "LSC POS Trans. Line";
    SourceTableTemporary = true;
    DeleteAllowed = false;
    Editable = false;
    Caption = 'Lineas en ventas';

    layout
    {
        area(Content)
        {
            repeater(Group)
            {
                field(lineNo; Rec."Line No.")
                {
                    Editable = false;
                    Visible = false;
                    Caption = 'Line No.';
                }
                field("Receipt No."; Rec."Receipt No.")
                {
                    Editable = false;
                    Visible = false;
                    Caption = 'Receipt No.';
                }
                field(Number; Rec.Number)
                {
                    Editable = false;
                    Visible = true;
                    Caption = 'Item No.';
                    trigger OnValidate()
                    var
                        myInt: Integer;
                    begin
                        AddOrUpdateLineToArrays(Rec);
                    end;
                }
                field(Descripcion; Rec.Description)
                {
                    Editable = false;
                    Style = Attention;
                    StyleExpr = (Rec."Entry Type" = Rec."Entry Type"::FreeText);
                    Caption = 'Descripcion';
                }
                field("Unit of Measure"; Rec."Unit of Measure")
                {
                    Editable = false;
                    Caption = 'Unidad de Medida';
                }
                field("Card Entry No."; Rec."Card Entry No.")
                {
                    Caption = 'Cantidad';
                    Editable = false;
                    trigger OnValidate()
                    begin
                        // Actualiza el campo Quantity de la tabla temporal con el valor del array
                        Rec.Modify(false);
                        AddOrUpdateLineToArrays(Rec);
                    end;
                }
                field(Price; Rec.Price)
                {
                    Editable = false;
                    Caption = 'Precio';
                }
                field("Discount %"; Rec."Discount %")
                {
                    Editable = false;
                    Caption = 'Descuento %';
                }
                field(Amount; Rec.Amount)
                {
                    Caption = 'Importe Desc.';
                    Editable = false;
                }
                field(Inventario; Rec."Indent No.")
                {
                    Editable = false;
                    Caption = 'Inventario';
                    Style = Strong;
                    StyleExpr = 'StrongAccent';
                }
                field("Store No."; Rec."Store No.")
                {
                    Editable = false;
                }

            }
            group(Totals)
            {
                field(TotalAmount; TotalAmount)
                {
                    ApplicationArea = All;
                    Editable = false;
                    Caption = 'Total Amount';
                }
                field(TotalDiscount; TotalDiscount)
                {
                    ApplicationArea = All;
                    Editable = false;
                    Caption = 'Total Discount';
                }
                field(Balance; Balance)
                {
                    ApplicationArea = All;
                    Editable = false;
                    Caption = 'Balance';
                }
            }
        }
    }
    actions
    {
        area(Processing)
        {
            action(InsertM)
            {
                ApplicationArea = All;
                Image = Insert;
                Visible = true;
                Caption = 'Insertar/Modificar';
                trigger OnAction()
                var
                    myInt: Integer;
                    item: Record Item;
                begin
                    CurrPage.Update(false);
                end;
            }
        }
    }



    var


        GlobalPosTransLine: Record "LSC POS Trans. Line" temporary;
        Arr_Item: array[150] of Code[20];
        Arr_Description: array[150] of Code[150];
        Arr_Unit_Of_Measure: array[150] of Code[20];
        Arr_Qty: array[150] of integer;
        Arr_EntryType: array[150] of integer;
        Inventary: array[150] of Integer;
        Store: Code[10];
        Terminal: Code[10];
        SalesStaff: Code[20];
        ManagerKey: Code[20];
        Customer: Code[20];
        MemberCard: Code[20];
        SchemeCode: Code[20];
        MemberPoints: Decimal;
        RequestFromID: Code[20];
        Arr_UnitPriceincVAT: array[150] of Decimal;
        Arr_Discount: array[150] of Decimal;
        Arr_Amount: array[150] of Decimal;
        Arr_EffDisc: array[150] of Decimal;
        Arr_EffAmt: array[150] of Decimal;
        TotalAmount: Decimal;
        TotalDiscount: Decimal;
        Balance: Decimal;
        BalanceVIP: Decimal;
        Response_Code: Text[10];
        Response_Text: Text;
        OnlyCalculate: Boolean;
        InventoryValue: Text;
        Producto: Text[150];
        Filtro: Option "Cod. Barra","Cod. Producto","Descripcion";
        Gfiltro: Integer;
        Cantidad: Integer;
        Return: Variant;
        wsprefac: codeunit "calculation process";
        Recibo: Code[20];
        PTransaction: Record "LSC POS Transaction";

    trigger OnOpenPage()
    var
        myInt: Integer;
    begin
        POSSESSION.SetValue('FSNOPENVAL', 'TRUE');
        AddOrUpdateLineToArrays(Rec);
    end;

    procedure GlobalPosTransa(PosTransaction: Record "LSC POS Transaction")
    var
        myInt: Integer;
    begin
        PTransaction := PosTransaction;
    end;

    procedure GetCurrentRecord(var PosTranLine: Record "LSC POS Trans. Line" temporary)
    begin
        if Rec.Find('-') then
            repeat
                PosTranLine := Rec;
                PosTranLine.Insert();
            until Rec.Next() = 0;
        Rec.DeleteAll(); // Limpia las líneas temporales después de copiar
    end;

    procedure RecordInv(var PosTranLine: Record "LSC POS Trans. Line" temporary)
    begin
        if Rec.Find('-') then
            repeat
                PosTranLine := Rec;
                PosTranLine.Insert();
            until Rec.Next() = 0;
    end;

    procedure RecibirProductos(JsonOb: JsonObject)
    var
        producto: JsonObject;
        array: JsonArray;
        jToken, token : JsonToken;
        codigo: Text[20];
        unidad: Text[20];
        cantidad: Integer;
        Initline, Change : Record "LSC POS Trans. Line" temporary;
        Line, i, RunPro : Integer;
        Invent: Boolean;
    begin
        RunPro := 0;
        Invent := true;
        Rec.DeleteAll(); // Limpia las líneas temporales antes de agregar nuevas
        Initline.DeleteAll(); // Limpia las líneas temporales antes de agregar nuevas
        if GlobalPosTransLine.Find('-') then begin
            repeat
                Initline := GlobalPosTransLine;
                Initline.Insert(true);
                Line := GlobalPosTransLine."Line No.";
            until GlobalPosTransLine.Next() = 0;
        end;


        if JsonOb.Get('receipt', jToken) then
            if not jToken.AsValue().IsNull then
                Recibo := jToken.AsValue().AsText();

        if JsonOb.Get('products', jToken) then // Seleccionar el arreglo "Arreglo
            if jToken.IsArray then   // Verificar que el token es un arreglo y convertirlo
                array := jToken.AsArray();

        // Recorre cada elemento del array recibido
        for i := 0 to array.Count() - 1 do begin
            if array.Get(i, token) and token.IsObject() then begin
                RunPro += 1;
                Initline.Init();
                producto := token.AsObject();
                // Extrae los valores del JSON
                if producto.Get('No_', jToken) then
                    if not jToken.AsValue().IsNull then
                        Initline.Number := jToken.AsValue().AsText();
                if producto.Get('Unit', jToken) then
                    if not jToken.AsValue().IsNull then
                        Initline."Unit of Measure" := jToken.AsValue().AsText();
                if producto.Get('quantity', jToken) then
                    if not jToken.AsValue().IsNull then
                        Initline."Card Entry No." := jToken.AsValue().AsInteger();
                if producto.Get('Description', jToken) then
                    if not jToken.AsValue().IsNull then
                        Initline.Description := jToken.AsValue().AsText();
                if producto.Get('Inventory', jToken) then
                    if not jToken.AsValue().IsNull then begin
                        Initline."Indent No." := jToken.AsValue().AsInteger();

                        /*if Invent then
                            if Initline."Indent No." = 0 then
                                Invent := false;*/
                        updateInventoryLookupTable(Initline.Number, Initline."Variant Code", PTransaction."Store No.", Initline."Indent No.");
                    end;
                // Crea una nueva línea temporal
                Line := Line + 1;
                Initline."Line No." := Line;
                Initline."Entry Type" := Initline."Entry Type"::Item;
                Initline.Insert();
            end;
        end;
        //Compress
        CompressLine(Initline, Change);

        if (RunPro = 1) /*and not Invent*/ then
            RunProcessLokkupInv(Initline);

        // Actualiza las líneas 
        POSSESSION.SetValue('FSNOPENVAL', 'NOT');
        AddOrUpdateLineToArrays(Change);
    end;

    procedure CompressLine(var Initline: Record "LSC POS Trans. Line" temporary; var Change: Record "LSC POS Trans. Line" temporary)
    var
        myInt: Integer;
    begin
        /*Change.DeleteAll(true);
        if Change.FindSet() then;*/
        Initline.SetRange(Initline."Entry Status", Initline."Entry Status"::" ");
        if Initline.Find('-') then
            repeat
                if Initline."Entry Type" = Initline."Entry Type"::Item then begin
                    Change.Reset();
                    Change.SetRange(Change."Receipt No.", Initline."Receipt No.");
                    Change.SetRange(Change.Number, Initline.Number);
                    Change.SetRange(Change."Unit of Measure", Initline."Unit of Measure");
                    Change.SetRange("Lot No.", Initline."Lot No.");
                    if not Change.FindFirst() then begin
                        Change.Init();
                        Change."Receipt No." := Initline."Receipt No.";
                        Change."Line No." := Initline."Line No.";
                        Change.Number := Initline.Number;
                        Change."Unit of Measure" := Initline."Unit of Measure";
                        Change."Card Entry No." := Initline."Card Entry No.";
                        Change."Indent No." := Initline."Indent No.";
                        Change.Amount := Initline.Amount;
                        Change.Price := Initline.Price;
                        Change.Description := Initline.Description;
                        Change."Entry Type" := Initline."Entry Type";
                        Change."Discount %" := Initline."Discount %";
                        Change."Discount Amount" := Initline."Discount Amount";
                        Change."Lot No." := Initline."Lot No.";
                        Change."Expiration Date" := Initline."Expiration Date";
                        Change.Insert(true);
                    end else begin
                        Change."Card Entry No." := Initline."Card Entry No.";
                        Change."Indent No." := Initline."Indent No.";
                        Change.Amount += Initline.Amount;
                        Change."Discount Amount" += Initline."Discount Amount";
                        Change."Discount %" := Rec."Discount Amount" / (Rec.Price * Rec."Card Entry No.");
                        Change."Discount %" := Round(Rec."Discount %" * 100, 0.1);
                        Change.Modify(true);
                    end;
                end else begin
                    Change.Init();
                    Change := Initline;
                    Change.Insert();
                end;
            until Initline.NEXT = 0;
    end;

    procedure updateInventoryLookupTable(Item: Code[20]; VariantCode: Code[10]; StoreNo: Code[20]; NetInventory: Decimal)
    var
        InventoryLookup: Record "LSC Inventory Lookup Table";
    begin
        InventoryLookup.Reset();
        InventoryLookup.SetRange(InventoryLookup."Item No.", Item);
        InventoryLookup.SetRange(InventoryLookup."Variant Code", VariantCode);
        InventoryLookup.SetRange(InventoryLookup."Store No.", StoreNo);
        if InventoryLookup.FindFirst() then begin
            InventoryLookup."Net Inventory" := NetInventory;
            InventoryLookup.Modify(true);
        end else begin
            InventoryLookup.Init();
            InventoryLookup."Item No." := Item;
            InventoryLookup."Variant Code" := VariantCode;
            InventoryLookup."Store No." := StoreNo;
            InventoryLookup."Net Inventory" := NetInventory;
            InventoryLookup.Insert();
        end;
    end;

    procedure InventoryLookupTable(Item: Code[20]; VariantCode: Code[10]; StoreNo: Code[20]; NetInventory: Decimal): Decimal
    var
        InventoryLookup: Record "LSC Inventory Lookup Table";
    begin
        InventoryLookup.Reset();
        InventoryLookup.SetRange(InventoryLookup."Item No.", Item);
        InventoryLookup.SetRange(InventoryLookup."Variant Code", VariantCode);
        InventoryLookup.SetRange(InventoryLookup."Store No.", StoreNo);
        if InventoryLookup.FindFirst() then begin
            exit(InventoryLookup."Net Inventory");
        end else begin
            // Si no se encuentra el registro, retornar 0 o un valor por defecto
            exit(0);
        end;
    end;

    // Actualizar el inventario de la línea actual
    local procedure ActualizarQuantity()
    var
        i: Integer;
        PAget: Page "ZY HyperLink";
    begin
        wsprefac.CalculationProcess(Arr_Item, Arr_Description, Arr_Unit_Of_Measure, Arr_Qty, Arr_EntryType, Arr_UnitPriceincVAT, Arr_Discount, Arr_Amount, Arr_EffDisc, Arr_EffAmt, TotalDiscount, TotalAmount, Balance, BalanceVIP, Customer, MemberCard, Response_Text, Inventary);
        for i := 1 to ArrayLen(Arr_Item) do begin
            if Arr_Item[i] <> '' then begin
                //Rec.Init();
                Rec."Line No." := i;
                Rec."Receipt No." := PTransaction."Receipt No.";
                Rec.Number := Arr_Item[i];
                Rec.Description := Arr_Description[i];
                Rec."Unit of Measure" := Arr_Unit_Of_Measure[i];
                Rec."Card Entry No." := Arr_Qty[i];
                Rec."Indent No." := Inventary[i];
                if Arr_EntryType[i] = 0 then
                    Rec."Entry Type" := Rec."Entry Type"::Item;
                if Arr_EntryType[i] = 2 then
                    Rec."Entry Type" := Rec."Entry Type"::PerDiscount;
                Rec."Store No." := PTransaction."Store No.";
                Rec."POS Terminal No." := PTransaction."POS Terminal No.";
                Rec."Sales Type" := PTransaction."Sales Type";
                Rec."Sales Staff" := SalesStaff;
                Rec."Created by Staff ID" := SalesStaff;
                Rec."Price" := Arr_UnitPriceincVAT[i];
                Rec."Discount %" := Arr_Discount[i];
                Rec.Amount := Arr_Amount[i];
                if not Rec.Insert(true) then begin
                    if Rec.Get(Rec."Receipt No.", Rec."Line No.") then begin//para evitar error de pagina no a sido actualizada
                        Rec.Number := Arr_Item[i];
                        Rec.Description := Arr_Description[i];
                        Rec."Unit of Measure" := Arr_Unit_Of_Measure[i];
                        Rec."Card Entry No." := Arr_Qty[i];
                        Rec."Indent No." := Inventary[i];
                        if Arr_EntryType[i] = 0 then
                            Rec."Entry Type" := Rec."Entry Type"::Item;
                        if Arr_EntryType[i] = 2 then
                            Rec."Entry Type" := Rec."Entry Type"::PerDiscount;
                        Rec."Store No." := PTransaction."Store No.";
                        Rec."POS Terminal No." := PTransaction."POS Terminal No.";
                        Rec."Sales Type" := PTransaction."Sales Type";
                        Rec."Sales Staff" := SalesStaff;
                        Rec."Created by Staff ID" := SalesStaff;
                        Rec."Price" := Arr_UnitPriceincVAT[i];
                        Rec."Discount %" := Arr_Discount[i];
                        Rec.Amount := Arr_Amount[i];
                        Rec.Modify(true);
                    end;
                end;
                IF NOT (POSSESSION.GetValue('FSNOPENVAL') = 'TRUE') THEN BEGIN
                    PAget.InsertItemsLines(Rec);
                    InsertRecordLine(Rec);//28981
                END;
            end;
        end;
        PAget.Update(false); // Actualiza la página de enlace
        CurrPage.Update(false); // Actualiza la página para reflejar los cambios
    end;


    local procedure AddOrUpdateLineToArrays(var Change: Record "LSC POS Trans. Line" temporary)
    var
        i: Integer;
    begin

        // Buscar la primera línea vacía o la que corresponde al Line No.
        i := 0;
        for i := 1 to 50 do begin
            if (Arr_Item[i] = '') or (Arr_Item[i] = Rec.Number) then
                break;
        end;

        if (i > 50) then
            Error('No hay espacio en el array para más líneas.');
        i := 0;
        // Asignar valores al array
        Change.Reset();
        if Change.Find('-') then
            repeat
                if Change.Number <> '' then begin
                    i += 1;
                    Arr_Item[i] := Change.Number;
                    Arr_Description[i] := Change.Description;
                    Arr_Unit_Of_Measure[i] := Change."Unit of Measure";
                    Arr_Qty[i] := Change."Card Entry No.";
                    Inventary[i] := Change."Indent No.";
                    Arr_EntryType[i] := Change."Entry Type";
                    Store := Change."Store No.";
                    Terminal := Change."POS Terminal No.";
                    SalesStaff := PTransaction."Sales Staff";
                    ManagerKey := PTransaction."Staff ID";
                    Customer := PTransaction."Customer No.";
                    MemberCard := PTransaction."Member Card No.";
                    SchemeCode := '';
                    MemberPoints := 0;
                    RequestFromID := 'POS';
                    Arr_UnitPriceincVAT[i] := 0;
                    Arr_Discount[i] := 0;
                    Arr_Amount[i] := 0;
                    Arr_EffDisc[i] := 0;
                    Arr_EffAmt[i] := 0;
                    TotalAmount := 0;
                    TotalDiscount := 0;
                    Balance := 0;
                    BalanceVIP := 0;
                    Response_Code := '';
                    Response_Text := '';
                    OnlyCalculate := true;
                end;
            until Change.Next() = 0;
        Change.DeleteAll();
        Rec.DeleteAll();
        CurrPage.Update(false);
        ActualizarQuantity();
    end;

    procedure InsertRecordLine(PosTransLine: Record "LSC POS Trans. Line")
    var
        Line: Integer;
    begin
        Rec.DeleteAll();
        PosTransLine.Reset();
        PosTransLine.SetRange("Receipt No.", PosTransLine."Receipt No.");
        PosTransLine.SetRange("POS Terminal No.", PosTransLine."POS Terminal No.");
        PosTransLine.SetRange("Entry Type", PosTransLine."Entry Type"::Item);
        PosTransLine.SetRange("Entry Status", PosTransLine."Entry Status"::" ");
        if PosTransLine.Find('-') then
            repeat
                Line := Line + 1;
                Rec.Init();
                Rec := PosTransLine;
                Rec."Card Entry No." := PosTransLine.Quantity;
                Rec."Line No." := Line;
                rec."Indent No." := InventoryLookupTable(PosTransLine.Number, PosTransLine."Variant Code", PosTransLine."Store No.", PosTransLine."Indent No.");
                if Rec.Insert(true) then;
                GlobalPosTransLine := Rec;
                if not GlobalPosTransLine.Insert(true) then
                    GlobalPosTransLine.Modify(true);
                if PTransaction.Get(PosTransLine."Receipt No.") then;
            until PosTransLine.Next() = 0;
        CurrPage.Update(false);
    end;

    procedure RunProcessLokkupInv(pPOSTransLineTemp: Record "LSC POS Trans. Line" temporary)
    var
        myInt: Integer;
        DeliveryOrder: Record "LSC Delivery Order";
        DeliveryStreet: Record "LSC Delivery Street";
        StoreLinkTmp: Record "FSN Store Link" temporary;
        StoreLinkLocal: Record "FSN Store Link";
        DivisorQtyPerValue: Decimal;
        InventoryLookUpTable: Record "LSC Inventory Lookup Table";
        DataText: Text;
        DistLoc: Code[20];
        SP: Text[250];
        Parameters: Record "FSN Parameter";
        QueryTxt: Text;
        CalProcess: Codeunit "calculation process";
        XmlString: Text;
        StoreLinksHTML: Text;
        Url: Text;
        PageImagen: Page TextCopy;
        InventoryInLookUpNet: Decimal;
        QtyTransaction: Decimal;
        THText: Text;
        TitleLabel: Label 'Salas Sugeridas - %1 - %2';
    begin
        Clear(DataText);
        IF (pPOSTransLineTemp."Entry Type" = pPOSTransLineTemp."Entry Type"::Item) AND (pPOSTransLineTemp."Entry Status" = pPOSTransLineTemp."Entry Status"::" ") THEN BEGIN

            InventoryInLookUpNet := 0;
            QtyTransaction := 0;
            DivisorQtyPerValue := 0;
            IF InventoryLookUpTable.GET(pPOSTransLineTemp.Number, pPOSTransLineTemp."Variant Code", POSSESSION.StoreNo(), pPOSTransLineTemp."Lot No.", pPOSTransLineTemp."Serial No.") THEN
                InventoryInLookUpNet := InventoryLookUpTable."Net Inventory"
            ELSE
                InventoryInLookUpNet := 0;

            QtyTransaction := GetQuantityTransaction(pPOSTransLineTemp);
            DivisorQtyPerValue := DivisorQtyPerUM(pPOSTransLineTemp.Number, pPOSTransLineTemp."Unit of Measure");

            IF DeliveryOrder.GET(Postransac.GetReceiptNo()) THEN BEGIN
                IF ((InventoryInLookUpNet / DivisorQtyPerValue) < (QtyTransaction / DivisorQtyPerValue)) THEN BEGIN
                    DeliveryStreet.RESET;
                    DeliveryStreet.SETRANGE(DeliveryStreet."FSN Alter Key", DeliveryOrder."FSN Alter Key");
                    IF DeliveryStreet.FINDFIRST THEN BEGIN

                        StoreLinkTmp.RESET;
                        StoreLinkTmp.DELETEALL;

                        StoreLinkLocal.RESET;
                        StoreLinkLocal.SETRANGE(StoreLinkLocal.Type, StoreLinkLocal.Type::StreetAlterKey);
                        StoreLinkLocal.SETRANGE(StoreLinkLocal."Parent Code", DeliveryStreet."FSN Alter Key Text");
                        StoreLinkLocal.SETFILTER(StoreLinkLocal."Km Between Points", '<=%1', DeliveryStreet."FSN Distance Allow Km.");
                        IF DeliveryStreet."FSN Distance Order Type" = DeliveryStreet."FSN Distance Order Type"::"Distance Driver" THEN BEGIN
                            StoreLinkLocal.SETCURRENTKEY(Sort, "Km Distance Driver");
                            StoreLinkLocal.SETFILTER(StoreLinkLocal."Km Distance Driver", '>0&<=%1', DeliveryStreet."FSN Distance Show Km.");
                        END;
                        IF StoreLinkLocal.FINDFIRST THEN
                            REPEAT

                                StoreLinkTmp.INIT();
                                StoreLinkTmp := StoreLinkLocal;
                                StoreLinkTmp."Time Driver Min." := 0;
                                IF InventoryLookUpTable.GET(pPOSTransLineTemp.Number, pPOSTransLineTemp."Variant Code", StoreLinkLocal."Store No.", pPOSTransLineTemp."Lot No.", pPOSTransLineTemp."Serial No.") THEN
                                    StoreLinkTmp."Time Driver Min." :=
                        ROUND(InventoryLookUpTable."Net Inventory" / DivisorQtyPerValue, 0.1, '<');

                                StoreLinkTmp.INSERT;
                            UNTIL StoreLinkLocal.NEXT = 0;

                        DelStreetModifyPriority(DeliveryStreet, StoreLinkTmp);
                        StoreLinkTmp.RESET;
                        StoreLinkTmp.SETCURRENTKEY("Km Distance Driver");
                        StoreLinkTmp.ASCENDING(TRUE);
                        StoreLinkTmp.SetFilter(StoreLinkTmp."Km Distance Driver", '<=%1', 10);
                        IF StoreLinkTmp.FIND('-') THEN BEGIN
                            repeat
                                StoreLinksHTML +=
                                '<tr>' +
                                    '<td>' + StoreLinkTmp."Store No." + '</td>' +
                                    '<td>' + StoreLinkTmp."Store Name" + '</td>' +
                                    '<td>' + Format(StoreLinkTmp."Link Type") + '</td>' +
                                    '<td>' + Format(StoreLinkTmp."Km Between Points") + '</td>' +
                                    '<td>' + Format(StoreLinkTmp."Km Distance Driver") + '</td>' +
                                    '<td>' + Format(StoreLinkTmp."Time Driver Min.") + '</td>' +
                                    '<td>' + Format(StoreLinkTmp."Sort") + '</td>';
                                StoreLinksHTML += '</tr>';
                            UNTIL StoreLinkTmp.Next() = 0;
                            THText := '<tr>' +
                        '            <th>No.</th>' +
                        '            <th>Tienda</th>' +
                        '            <th>KM Tipo</th>' +
                        '            <th>Km Planos</th>' +
                        '            <th>Km Moto</th>' +
                        '            <th>Inventario</th>' +
                        '            <th>Prioridad</th>' +
                        '        </tr>';
                            Url := CalProcess.GenerateHTML(StoreLinksHTML, THText, StrSubstNo(TitleLabel, pPOSTransLineTemp.Number, pPOSTransLineTemp.Description));
                            //Url := GenerateHTML(StoreLinksHTML, pPOSTransLineTemp);
                            PageImagen.CopyTxt(Url);
                            PageImagen.Run();
                        END;
                    END;
                end;
            END;
        END;
    end;

    //divisor por unidad de medida
    procedure DivisorQtyPerUM(pItemNo: Code[20]; pUM: Code[10]): Decimal
    var
        ItemUnitOfMeasure_l: Record "Item Unit of Measure";
    begin

        IF NOT ItemUnitOfMeasure_l.GET(pItemNo, pUM) THEN
            EXIT(1.0);

        IF ItemUnitOfMeasure_l."Qty. per Unit of Measure" = 0 THEN
            EXIT(1.0)
        ELSE
            EXIT(ItemUnitOfMeasure_l."Qty. per Unit of Measure");
    end;

    //optiene cantidad de producto de la trasaccion actual, para validacion de inventario
    procedure GetQuantityTransaction(POSTransL: Record "LSC POS Trans. Line"): Decimal
    var
        POSTransLineBK: Record "LSC POS Trans. Line";
        Qty: Decimal;
    begin
        POSTransLineBK.RESET;
        POSTransLineBK.SETCURRENTKEY("Receipt No.", "Entry Type", "Entry Status");
        POSTransLineBK.SETRANGE(POSTransLineBK."Receipt No.", POSTransL."Receipt No.");
        POSTransLineBK.SETRANGE(POSTransLineBK."Entry Type", POSTransLineBK."Entry Type"::Item);
        POSTransLineBK.SETRANGE(POSTransLineBK."Entry Status", POSTransLineBK."Entry Status"::" ");
        POSTransLineBK.SETRANGE(POSTransLineBK.Number, POSTransL.Number);
        IF POSTransLineBK.FINDSET THEN BEGIN
            Qty := 0;
            REPEAT
                Qty += POSTransLineBK.Quantity * DivisorQtyPerUM(POSTransLineBK.Number, POSTransLineBK."Unit of Measure");
            UNTIL POSTransLineBK.NEXT = 0;
        END;

        Qty += POSTransL."Card Entry No." * DivisorQtyPerUM(POSTransL.Number, POSTransL."Unit of Measure");

        EXIT(Qty);
    end;

    //Hace selecion de las tiendas por Prioridad
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

    trigger OnClosePage()
    var
        myInt: Integer;
    begin
        POSSESSION.SetValue('FSNLASTLINE', '0');
    end;

    procedure LineLast(): Integer
    var
        LAST: Integer;
        LineFilt: Record "LSC POS Trans. Line";
    begin
        LineFilt.Reset();
        LineFilt.SetRange(LineFilt."Receipt No.", Postransac.GetReceiptNo());
        LineFilt.SetRange(LineFilt."Entry Type", LineFilt."Entry Type"::Item);
        LineFilt.SetRange(LineFilt."Entry Status", LineFilt."Entry Status"::" ");
        if LineFilt.FindLast() then
            exit(LineFilt."Line No." + 1000)
        else begin
            IF POSSESSION.GetValue('FSNLASTLINE') in ['0', ''] THEN begin
                POSSESSION.SetValue('FSNLASTLINE', '1');
                exit(1);
            end ELSE begin
                if Evaluate(LAST, POSSESSION.GetValue('FSNLASTLINE')) then begin
                    LAST += 1;
                    POSSESSION.SetValue('FSNLASTLINE', Format(LAST));
                    exit(LAST);
                end else begin
                    LAST += 1;
                    POSSESSION.SetValue('FSNLASTLINE', Format(LAST));
                    exit(LAST);
                end;
            end;
        end;

    end;

    var
        Postransac: Codeunit "LSC POS Transaction";
        POSSESSION: Codeunit "LSC POS Session";

}